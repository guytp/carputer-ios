#import "CommandClient.h"
#import "StartCommandThreadDefinition.h"
#import "CommandClientResponse.h"

@interface CommandClient ()
- (void)disconnectWithoutNotification;
- (void) clearCurrentCommandThreadDetails;
@end

@implementation CommandClient
@synthesize hostname = _hostname;
@synthesize port = _port;
@synthesize delegate = _delegate;
@synthesize isConnected = _isConnected;
@synthesize isConnecting = _isConnecting;
@synthesize serialNumber = _serialNumber;
@synthesize lastDataReceived = _lastDataReceived;

NSString * kCommandClientErrorDomain = @"CommandClientErrorDomain";

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Create lock object
    _commandLockObject = [[NSObject alloc] init];
    
    // Start status check timer
    _statusCheckTimer = [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(statusCheckTimerTick:) userInfo:nil repeats:YES];
    
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
    NSLog(@"Command client %@ is connecting", _hostname);
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)_hostname, _port, &readStream, &writeStream);
    _commandInputStream = (__bridge_transfer NSInputStream *)readStream;
    [_commandInputStream setDelegate:self];
    _commandOutputStream = (__bridge_transfer NSOutputStream *)writeStream;
    [_commandOutputStream setDelegate:self];
    [_commandInputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_commandOutputStream scheduleInRunLoop:[NSRunLoop mainRunLoop] forMode:NSDefaultRunLoopMode];
    [_commandInputStream open];
    [_commandOutputStream open];
    _connectionStartTime = [NSDate date];
    return;
}

- (void)disconnect
{
    // Disconnect
    [self disconnectWithoutNotification];
    
    // Signify our delegate
    if (self.delegate)
        [self.delegate commandClientDisconnected:self];
}


- (void)disconnectWithoutNotification {
    NSLog(@"Command client %@ is disconnecting", _hostname);
    [_commandInputStream close];
    [_commandOutputStream close];
    _commandInputStream = nil;
    _commandOutputStream = nil;
    _isConnected = NO;
    _isConnecting = NO;
    _connectionStartTime = nil;
}

- (void)sendCommand:(CommandBase *) command withTarget:(id)target successSelector:(SEL)successSelector failedSelector:(SEL)failedSelector {
    StartCommandThreadDefinition * startCommandThreadDefinition = [[StartCommandThreadDefinition alloc] init];
    startCommandThreadDefinition.command = command;
    startCommandThreadDefinition.target = target;
    startCommandThreadDefinition.successSelector = successSelector;
    startCommandThreadDefinition.failedSelector = failedSelector;
    [NSThread detachNewThreadSelector:@selector(runCommandThreadEntry:) toTarget:self withObject:startCommandThreadDefinition];
}

- (void)runCommandThreadEntry:(StartCommandThreadDefinition *)startCommandThreadDefinition {
    // Parse parameters to thread
    CommandBase * command = startCommandThreadDefinition.command;
    [[NSThread currentThread] setName:[NSString stringWithFormat:@"Run Command: %@", command]];
    //NSLog(@"Command client %@ queued command %@", _hostname, command);
    id target = startCommandThreadDefinition.target;
    SEL successSelector = startCommandThreadDefinition.successSelector;
    SEL failedSelector = startCommandThreadDefinition.failedSelector;
    
    @synchronized (_commandLockObject)
    {
        // Wait to be connected
        while (!_isConnected)
            [NSThread sleepForTimeInterval:0.1];
        //NSLog(@"Command client %@ executing command %@", _hostname, command);
        
        // Store current thread details
        _currentThread = [NSThread currentThread];
        _currentThreadCommandDefinition = startCommandThreadDefinition;
        _currentThreadStartTime = [NSDate date];
        
        // Raise error if not connected
        if (!_commandOutputStream)
        {
            if (!failedSelector) return;
            NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorNotConnected userInfo:nil];
            [target performSelectorInBackground:failedSelector withObject:error];
            [self clearCurrentCommandThreadDetails];
            return;
        }
        if (!command)
        {
            if (!failedSelector) return;
            NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorCommandNotSupplied userInfo:nil];
            [target performSelectorInBackground:failedSelector withObject:error];
            [self clearCurrentCommandThreadDetails];
            return;
        }
        
        // Get the serialised command and write it to output buffer
        NSError * serialiseError;
        NSData * buffer = [command serialiseWithError:&serialiseError];
        if (serialiseError)
        {
            if (!failedSelector) return;
            NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorSerialiseFail userInfo:nil];
            [target performSelectorInBackground:failedSelector withObject:error];
            [self clearCurrentCommandThreadDetails];
            return;
        }
        [_commandOutputStream write:[buffer bytes] maxLength:[buffer length]];
        
        // Read the response
        while (![_commandInputStream hasBytesAvailable])
        {
            if ([NSThread currentThread].isCancelled)
                return;
            [NSThread sleepForTimeInterval:0.1];
        }
        NSMutableData * readBuffer = [[NSMutableData alloc] init];
        uint8_t buf[1024];
        NSInteger bytesRead = 0;
        int length = 0;
        int totalBytesRead = 0;
        int nextBytesToRead = 4;
        while ((bytesRead = [_commandInputStream read:buf maxLength:nextBytesToRead]) > 0)
        {
            // Return if cancelled
            self.lastDataReceived = [NSDate date];
            if ([NSThread currentThread].isCancelled)
                return;
            
            // If we read more than what we expected disconnect as an error
            if (bytesRead > nextBytesToRead)
            {
                [self disconnect];
                [self clearCurrentCommandThreadDetails];
                return;
            }
            
            // Read this chunk of the buffer
            totalBytesRead += bytesRead;
            [readBuffer appendBytes:(const void *)buf length:bytesRead];
            
            // If we've read more than 4 bytes this indicates the total available length we want to red in this loop
            if ((length == 0) && (totalBytesRead >= 4))
            {
                NSData * lengthData = [readBuffer subdataWithRange:NSMakeRange(0, 4)];
                length = ntohl(*(int*)([lengthData bytes]));
                if (length == 0)
                {
                    // There's no data as part of this message so just return firing failed seletor
                    // if we were expecting data otherwise success
                    if (command.ResponseExpected)
                    {
                        if (!failedSelector) return;
                        NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorMissingResponse userInfo:nil];
                        [target performSelectorInBackground:failedSelector withObject:error];
                    }
                    else if (successSelector)
                        [target performSelectorInBackground:successSelector withObject:[[CommandClientResponse alloc] initWithClient:self response:nil]];
                    [self clearCurrentCommandThreadDetails];
                    return;
                }
                
                // Clear out read buffer
                [readBuffer setLength:0];
                totalBytesRead = 0;
            }
            
            // Determine how many, if any, more bytes we want to read
            if (length == 0)
                nextBytesToRead = 4 - totalBytesRead;
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
        
        // Throw an error if we weren't expecting a response object
        if (!command.ResponseExpected)
        {
            if (!failedSelector) return;
            NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorUnexpectedResponse userInfo:nil];
            [target performSelectorInBackground:failedSelector withObject:error];
            [self clearCurrentCommandThreadDetails];
            return;
        }
        
        // Read out length then the JSON response object and parse to the command if required
        NSError * parseError;
        id jsonObject = [NSJSONSerialization JSONObjectWithData:readBuffer options:kNilOptions error:&parseError];
        id result;
        if (!parseError)
            result = [command parseResponse:jsonObject withError:&parseError];
        if (parseError || !result)
        {
            if (!failedSelector) return;
            NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:parseError ? CommandClientErrorResponseParseFail : CommandClientErrorMissingResponse userInfo:nil];
            [target performSelectorInBackground:failedSelector withObject:error];
            [self clearCurrentCommandThreadDetails];
            return;
        }
        
        // If this was successful then call back
        if (successSelector)
            [target performSelectorInBackground:successSelector withObject:[[CommandClientResponse alloc] initWithClient:self response:result]];
        [self clearCurrentCommandThreadDetails];
    }
}

- (void) clearCurrentCommandThreadDetails {
    _currentThread = nil;
    _currentThreadCommandDefinition = nil;
    _currentThreadStartTime = nil;
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    if ((eventCode == NSStreamEventOpenCompleted) && (_isConnecting))
    {
        _isConnected = YES;
        _isConnecting = NO;
        _connectionStartTime = nil;
        NSLog(@"Command client %@ is connected", _hostname);
        if (self.delegate)
            [self.delegate commandClientConnected:self];
    }
    else if ((_isConnected) && ((eventCode == NSStreamEventEndEncountered) || (eventCode == NSStreamEventErrorOccurred)))
    {
        NSLog(@"Command client %@ is disconnecting due to status %lu", _hostname, (unsigned long)eventCode);
        [self disconnect];
    }
    else if ((_isConnecting) && (eventCode == NSStreamEventErrorOccurred))
    {
        [self disconnectWithoutNotification];
        NSError * error = [aStream streamError];
        NSLog(@"Command client %@ connection failed due to status %lu %@", _hostname, (unsigned long)eventCode, [error localizedDescription]);
        if (self.delegate)
            [self.delegate commandClient:self connectFailedForReason:[error localizedDescription]];
    }
}

- (void)statusCheckTimerTick:(NSTimer *)timer {
    // If we're connecting check if the maximum connection time has elapsed
    if ((_isConnecting) && (_connectionStartTime))
    {
        if ([_connectionStartTime timeIntervalSinceNow] < -1)
        {
            // A timeout has elapsed so trigger a disconnect and fire a connection failure
            NSLog(@"Command client %@ failed to connect due to connect timeout", _hostname);
            [self disconnectWithoutNotification];
            if (self.delegate)
                [self.delegate commandClient:self connectFailedForReason:@"Connection timed out"];
        }
        return;
    }
    
    // If we're not connected don't do the check
    if (!_isConnected)
    {
        if (_currentThread)
        {
            [_currentThread cancel];
            SEL failedSelector = _currentThreadCommandDefinition.failedSelector;
            id target = _currentThreadCommandDefinition.target;
            [self clearCurrentCommandThreadDetails];
            if (failedSelector)
            {
                NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorRequestTimeout userInfo:nil];
                [target performSelectorInBackground:failedSelector withObject:error];
            }
            NSLog(@"Command client %@ failed a command due to read disconnect in status check", _hostname);
        }
        return;
    }
    
    // Check the socket is still open and valid
    for (int i = 0; i < 2; i++)
    {
        NSStreamStatus status = (i == 0 ? _commandInputStream : _commandOutputStream).streamStatus;
        if ((status == NSStreamStatusNotOpen) || (status == NSStreamStatusClosed) || (status == NSStreamStatusError))
        {
            NSLog(@"Command client %@ failed status check due to status %lu", _hostname, (unsigned long)status);
            [self disconnect];
            return;
        }
    }
    
    // If a command is in-progress ensure it hasn't timed out.  If it has terminate that command
    // and return a failure notification.
    if ((_currentThread) && ([_currentThreadStartTime timeIntervalSinceNow] < -3))
    {
        SEL failedSelector = _currentThreadCommandDefinition.failedSelector;
        id target = _currentThreadCommandDefinition.target;
        [_currentThread cancel];
        [self clearCurrentCommandThreadDetails];
        if (!failedSelector) return;
        NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorRequestTimeout userInfo:nil];
        [target performSelectorInBackground:failedSelector withObject:error];
        NSLog(@"Command client %@ failed a command due to read timeout", _hostname);
        [self disconnect];
    }
}
@end