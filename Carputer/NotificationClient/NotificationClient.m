#import "NotificationClient.h"
#import "NotificationProcessorBase.h"
#import "AudioStatusNotificationProcessor.h"
#import "AudioLibraryUpdateNotificationProcessor.h"
#import "AudioArtworkAvailableNotificationProcessor.h"
#import "NSDictionary+Dictionary_ContainsKey.h"

NSString * kNotificationClientNotificationName = @"NotificationClientNotification";

@implementation NotificationClient

static NSMutableDictionary * _lastNotifications = nil;

@synthesize hostname = _hostname;
@synthesize port = _port;
@synthesize delegate = _delegate;
@synthesize isConnected = _isConnected;
@synthesize isConnecting = _isConnecting;
@synthesize lastDataReceived = _lastDataReceived;

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Setup class
    _statusCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(statusCheckTimerTick:) userInfo:nil repeats:YES];
    _processors = [NSMutableArray arrayWithObjects:[[AudioStatusNotificationProcessor alloc] init], [[AudioLibraryUpdateNotificationProcessor alloc] init], [[AudioArtworkAvailableNotificationProcessor alloc] init], nil];
    if (!_lastNotifications)
        _lastNotifications = [NSMutableDictionary dictionary];
    
    
    // Return self
    return self;
}

- (id)initWithHostname:(NSString *)hostname port:(ushort)port serialNumber:(NSString *)serialNumber {
    // Call to self
    self = [self init];
    if (!self)
        return nil;
    
    // Store properties
    _hostname = hostname;
    _port = port;
    _serialNumber = serialNumber;
    
    return self;
}

- (void)dealloc {
    [_statusCheckTimer invalidate];
    _statusCheckTimer = nil;
    [self disconnectWithoutNotification];
}

- (void)connect {
    // Return if already connected
    if ((_isConnecting) || (_isConnected))
        return;
    
    // Create a stream pairing and open the conection
    _isConnected = NO;
    _isConnecting = YES;
    NSLog(@"Notification client %@ is connecting", _hostname);
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)_hostname, _port, &readStream, &writeStream);
    _inputStream = (__bridge_transfer NSInputStream *)readStream;
    [_inputStream setDelegate:self];
    _outputStream = (__bridge_transfer NSOutputStream *)writeStream;
    [_outputStream setDelegate:self];
    [_inputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_outputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_inputStream open];
    [_outputStream open];
    _connectionStartTime = [NSDate date];
    return;
}

- (void)disconnect
{
    // Disconnect
    [self disconnectWithoutNotification];
    
    // Signify our delegate
    if (self.delegate)
        [self.delegate notificationClientDisconnected:self];
}


- (void)disconnectWithoutNotification {
    NSLog(@"Notification client %@ is disconnecting", _hostname);
    [_processingThread cancel];
    _processingThread = nil;
    [_inputStream close];
    [_outputStream close];
    _inputStream = nil;
    _outputStream = nil;
    _isConnected = NO;
    _isConnecting = NO;
    _connectionStartTime = nil;
}

- (void)processingMainThread {
    // Store the thread
    _processingThread = [NSThread currentThread];
    [_processingThread setName:[NSString stringWithFormat:@"Notification Parsig: %@", self.hostname]];
    NSLog(@"Notification parsing started for %@", _hostname);
    
    // Raise error if not connected
    if (!_outputStream)
    {
        [self disconnect];
        return;
    }
    
    // Continunually run as long as we're connected
    while (![NSThread currentThread].isCancelled)
    {
        // Wait for a notification
        while (![_inputStream hasBytesAvailable])
        {
            if ([NSThread currentThread].isCancelled)
                return;
            [NSThread sleepForTimeInterval:0.1];
        }
        NSMutableData * readBuffer = [[NSMutableData alloc] init];
        uint8_t buf[1024];
        unsigned int bytesRead = 0;
        int length = 0;
        ushort opCode = 0;
        ushort notificationCode = 0;
        int totalBytesRead = 0;
        int nextBytesToRead = 8;
        while ((bytesRead = [_inputStream read:buf maxLength:nextBytesToRead]) > 0)
        {
            // Return if cancelled
            self.lastDataReceived = [NSDate date];
            if ([NSThread currentThread].isCancelled)
                return;
            
            // If we read more than what we expected disconnect as an error
            if (bytesRead > nextBytesToRead)
            {
                [self disconnect];
                return;
            }
            
            // Read this chunk of the buffer
            totalBytesRead += bytesRead;
            [readBuffer appendBytes:(const void *)buf length:bytesRead];
            
            // If we've read more than 8 bytes this indicates the total available length we want to red in this loop
            if ((length == 0) && (totalBytesRead >= 8))
            {
                NSData * rawData = [readBuffer subdataWithRange:NSMakeRange(0, 2)];
                notificationCode = ntohs(*(ushort*)([rawData bytes]));
                rawData = [readBuffer subdataWithRange:NSMakeRange(2, 2)];
                opCode = ntohs(*(ushort*)([rawData bytes]));
                rawData = [readBuffer subdataWithRange:NSMakeRange(4, 4)];
                length = ntohl(*(int*)([rawData bytes]));
                if (length == 0)
                    break;
                
                // Clear out read buffer
                [readBuffer setLength:0];
                totalBytesRead = 0;
            }
            
            // Determine how many, if any, more bytes we want to read
            if (length == 0)
                nextBytesToRead = 8 - totalBytesRead;
            else
            {
                nextBytesToRead = length - totalBytesRead;
                if (nextBytesToRead > 1024)
                    nextBytesToRead = 1024;
            }
            
            // If we've read all data then break out
            if (nextBytesToRead < 1)
                break;
        }
        
        // Return gracefully if we've been cancelled
        if ([NSThread currentThread].isCancelled)
            return;
        
        // Determine which of our processors can handle this
        NotificationProcessorBase * processor = nil;
        for (NotificationProcessorBase * p in _processors)
            if ((p.opCode == opCode) && (p.notificationCode == notificationCode))
            {
                processor = p;
                break;
            }
        if (!processor)
        {
            NSLog(@"Notification client unable to process %d.%d notification", notificationCode, opCode);
            continue;
        }
        
        // Parse the JSON
        NSError * parseError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:readBuffer options:kNilOptions error:&parseError];
        if (parseError)
        {
            NSString * stringJson = [[NSString alloc] initWithData:readBuffer encoding:NSUTF8StringEncoding];
            NSLog(@"Notification client unable to parse JSON for %d.%d notification\r\n\r\n%@\r\n\r\n%@", notificationCode, opCode, stringJson, parseError);
            continue;
        }
        
        // Get the notification object and send it out
        id notificationObject = [processor notificationObjectForJson:jsonObject deviceSerialNumber:_serialNumber];
        if (parseError || !notificationObject)
        {
            NSLog(@"Notification client has no object to post for %d.%d notification", notificationCode, opCode);
            continue;
        }
        NSString * notificationTypeKey = NSStringFromClass([notificationObject class]);
        @synchronized (_lastNotifications)
        {
            [_lastNotifications setObject:notificationObject forKey:notificationTypeKey];
        }
//        NSLog(@"Notification client posting %d.%d notification as %@", notificationCode, opCode, notificationObject);
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationClientNotificationName object:notificationObject];
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if ((eventCode == NSStreamEventOpenCompleted) && (_isConnecting))
    {
        _isConnected = YES;
        _isConnecting = NO;
        _connectionStartTime = nil;
        [NSThread detachNewThreadSelector:@selector(processingMainThread) toTarget:self withObject:nil];
        NSLog(@"Notification client %@ is connected", _hostname);
        if (self.delegate)
            [self.delegate notificationClientConnected:self];
    }
    else if ((_isConnected) && ((eventCode == NSStreamEventEndEncountered) || (eventCode == NSStreamEventErrorOccurred)))
    {
        NSLog(@"Notification client %@ is disconnecting due to status %d", _hostname, eventCode);
        [self disconnect];
    }
    else if ((_isConnecting) && (eventCode == NSStreamEventErrorOccurred))
    {
        [self disconnectWithoutNotification];
        NSError * error = [aStream streamError];
        NSLog(@"Notification client %@ connection failed due to status %d %@", _hostname, eventCode, [error localizedDescription]);
        if (self.delegate)
            [self.delegate notificationClient:self connectFailedForReason:[error localizedDescription]];
    }
}

- (void)statusCheckTimerTick:(NSTimer *)timer {
    // If we're connecting check if the maximum connection time has elapsed
    if ((_isConnecting) && (_connectionStartTime))
    {
        if ([_connectionStartTime timeIntervalSinceNow] < -1)
        {
            // A timeout has elapsed so trigger a disconnect and fire a connection failure
            NSLog(@"Notification client %@ failed to connect due to connect timeout", _hostname);
            [self disconnectWithoutNotification];
            if (self.delegate)
                [self.delegate notificationClient:self connectFailedForReason:@"Connection timed out"];
        }
        return;
    }
    
    // Check the socket is still open and valid
    for (int i = 0; i < 2; i++)
    {
        NSStreamStatus status = (i == 0 ? _inputStream : _outputStream).streamStatus;
        if ((status == NSStreamStatusNotOpen) || (status == NSStreamStatusClosed) || (status == NSStreamStatusError))
        {
            NSLog(@"Notification client %@ failed status check due to status %d", _hostname, status);
            [self disconnect];
            return;
        }
    }
}

+ (id)lastNotificationOfType:(NSString *)type {
    @synchronized (_lastNotifications)
    {
        if ([_lastNotifications containsKey:type])
            return [_lastNotifications objectForKey:type];
        else
            return nil;
    }
}
@end