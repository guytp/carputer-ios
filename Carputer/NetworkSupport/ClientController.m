#import "ClientController.h"
#import "NSDictionary+Dictionary_ContainsKey.h"
#import "CarputerDevice.h"
#import "CommandClient.h"
#import "AudioLibraryGetCommand.h"
#import "AudioFileFactory.h"
#import "NotificationClient.h"
#import "CommandClientResponse.h"

@implementation ClientController
static ClientController * _applicationInstance;
@synthesize delegate;

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Setup class defaults
    _carputerDevices = [[NSMutableDictionary alloc] init];
    _commandClients = [[NSMutableDictionary alloc] init];
    _notificationClients = [[NSMutableDictionary alloc] init];
    _lastConnectedCount = 0;
    _lastTotalCount = 0;
    
    // Create listening socket
    _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
    NSError *error = nil;
    if (![_udpSocket bindToPort:4200 error:&error])
        NSLog(@"Error binding to multicast discovery port: %@", error);
    else
    {
        if(![_udpSocket joinMulticastGroup:@"239.42.0.1" error:&error])
            NSLog(@"Error connecting to multicast discovery group: %@", error);
        else
        {
            if (![_udpSocket beginReceiving:&error])
                NSLog(@"Error starting receiving from multicast discovery: %@", error);
            else
            {
                NSLog(@"Multicast discovery started");
                if (![_udpSocket beginReceiving:&error])
                    NSLog(@"Failed to begin receiving from discovery socket: %@", error);
                else
                    NSLog(@"Started receiving from discovery socket");
            }
        }
    }
    
    // Start status check thread
    [NSThread detachNewThreadSelector:@selector(statusCheckThread) toTarget:self withObject:nil];
    
    // Return self
    return self;
}

+ (void)initialize {
    // Call to base
    [super initialize];
    
    // Create application instance
    _applicationInstance = [[ClientController alloc] init];
}

+ (ClientController *)applicationInstance {
    return _applicationInstance;
}

- (void)udpSocket:(GCDAsyncUdpSocket *)sock didReceiveData:(NSData *)data fromAddress:(NSData *)address withFilterContext:(id)filterContext {
    // Attempt to parse JSON object from discovery packet
    NSError * error;
    NSDictionary * jsonObject = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (error)
    {
        NSLog(@"Failed to parse discovery packet: %@", error);
        return;
    }
    if (![[jsonObject class] isSubclassOfClass:[NSDictionary class]])
    {
        NSLog(@"Json object is not a dictionary");
        return;
    }
    
    // Attempt to read values from discovery packet
    bool audioSupport = false;
    NSString * hostname = nil;
    ushort notificationPort = 0;
    ushort commandPort = 0;
    if ([jsonObject containsKey:@"AudioSupport"])
        audioSupport = [(NSNumber *) [jsonObject valueForKey:@"AudioSupport"] boolValue];
    if ([jsonObject containsKey:@"Hostname"])
        hostname = [jsonObject valueForKey:@"Hostname"];
    if ([jsonObject containsKey:@"NotificationPort"])
        notificationPort = (ushort)[(NSNumber *) [jsonObject valueForKey:@"NotificationPort"] intValue];
    if ([jsonObject containsKey:@"CommandPort"])
        commandPort = (ushort)[(NSNumber *) [jsonObject valueForKey:@"CommandPort"] intValue];
    
    // If core values are missing return
    if ((!hostname) || (notificationPort < 1) || (commandPort < 1))
    {
        NSLog(@"Discovery packet missing core information, discarding");
        return;
    }
    NSString * ipAddress = [GCDAsyncUdpSocket hostFromAddress:address];
    
    // Check if we have this server already, if not then add a new server to the list, otherwise
    // update its last seen time
    NSString * hostKey = [NSString stringWithFormat:@"%@:%@:%d:%d", ipAddress, hostname, commandPort, notificationPort];
    if ([_carputerDevices containsKey:hostKey])
    {
        CarputerDevice * device = [_carputerDevices valueForKey:hostKey];
        device.lastUpdated = [NSDate date];
    }
    else
    {
        CarputerDevice * device = [[CarputerDevice alloc] initWithIpAddress:ipAddress hostname:hostname commandPort:commandPort notificationPort:notificationPort audioSupport:audioSupport];
        @synchronized (_carputerDevices)
        {
            [_carputerDevices setObject:device forKey:hostKey];
        }
        NSLog(@"%@ discovered and added to our list", hostKey);
    }
}

- (void)statusCheckThread {
    [[NSThread currentThread] setName:@"Client Controller Status Check"];
    while (![NSThread currentThread].isCancelled)
    {
        // Remove any timed out devices
        @synchronized (_carputerDevices)
        {
            NSArray * allKeys = [_carputerDevices allKeys];
            for (NSString * key in allKeys)
            {
                // Ignore if we've seen it recently
                CarputerDevice * device = [_carputerDevices valueForKey:key];
                if ([device.lastUpdated timeIntervalSinceNow] > -3)
                    continue;
                
                // Remove from list
                NSLog(@"%@:%@:%d:%d has timed out, removing from our known devices", device.ipAddress, device.hostname, device.commandPort, device.notificationPort);
                [_carputerDevices removeObjectForKey:key];
                [_notificationClients removeObjectForKey:key];
                [_commandClients removeObjectForKey:key];
                
                // Disconnect if required
                CommandClient * commandClient = [_commandClients valueForKey:key];
                if ((commandClient) && (commandClient.isConnected))
                    [commandClient disconnect];
                NotificationClient * notificationClient = [_notificationClients valueForKey:key];
                if ((notificationClient) && (notificationClient.isConnected))
                    [notificationClient disconnect];
            }
            
            // Reconnect any disconnected command clients
            allKeys = [_carputerDevices allKeys];
            for (NSString * key in allKeys)
            {
                // Ignore if we're connected
                CommandClient * commandClient = [_commandClients valueForKey:key];
                if ((commandClient.isConnected) || (commandClient.isConnecting))
                    continue;
                
                // Request a reconnection if client exists, otherwise create a new client
                CarputerDevice * device = [_carputerDevices valueForKey:key];
                if (commandClient)
                    NSLog(@"%@:%@:%d:%d has disconnected, reconnecting", device.ipAddress, device.hostname, device.commandPort, device.notificationPort);
                else
                {
                    commandClient = [[CommandClient alloc] initWithHostname:device.ipAddress port:device.commandPort];
                    commandClient.delegate = self;
                    [_commandClients setObject:commandClient forKey:key];
                    NSLog(@"%@:%@:%d:%d is new, connecting", device.ipAddress, device.hostname, device.commandPort, device.notificationPort);
                }
                [commandClient connect];
            }
            // Reconnect any disconnected notification clients
            for (NSString * key in allKeys)
            {
                // Ignore if we're connected
                NotificationClient * notificationClient = [_notificationClients valueForKey:key];
                if ((notificationClient.isConnected) || (notificationClient.isConnecting))
                    continue;
                
                // Request a reconnection if client exists, otherwise create a new client
                CarputerDevice * device = [_carputerDevices valueForKey:key];
                if (notificationClient)
                    NSLog(@"%@:%@:%d:%d (notification) has disconnected, reconnecting", device.ipAddress, device.hostname, device.commandPort, device.notificationPort);
                else
                {
                    notificationClient = [[NotificationClient alloc] initWithHostname:device.ipAddress port:device.notificationPort];
                    notificationClient.delegate = self;
                    [_notificationClients setObject:notificationClient forKey:key];
                    NSLog(@"%@:%@:%d:%d (notification) is new, connecting", device.ipAddress, device.hostname, device.commandPort, device.notificationPort);
                }
                [notificationClient connect];
            }

            
            // Get total counts
            int connectedCount = 0;
            int totalCount = [_carputerDevices count];
            for (CommandClient * commandClient in [_commandClients allValues])
                if (commandClient.isConnected)
                    connectedCount++;
            if ((self.delegate) && ((connectedCount != _lastConnectedCount) || (totalCount != _lastTotalCount)))
                [self.delegate clientController:self totalClients:totalCount connectedClients:connectedCount];
            _lastConnectedCount = connectedCount;
            _lastTotalCount = totalCount;
        }
        
        // Wait to re-loop
        [NSThread sleepForTimeInterval:1];
    }
}


- (void)sendCommand:(CommandBase *) command withTarget:(id)target successSelector:(SEL)successSelector failedSelector:(SEL)failedSelector {
    // Try to find suitable clients
    NSMutableArray * connectedClients = [[NSMutableArray alloc] init];
    @synchronized (_carputerDevices)
    {
        for (CommandClient * client in [_commandClients allValues])
            if (client.isConnected)
                [connectedClients addObject:client];
    }
    
    // Call failure if no clients found
    if ([connectedClients count] < 1)
    {
        NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorNotConnected userInfo:nil];
        if (!failedSelector)
            [target performSelectorOnMainThread:failedSelector withObject:error waitUntilDone:NO];
        return;
    }
    
    // Call each client with the command
    for (CommandClient * client in connectedClients)
        [client sendCommand:command withTarget:target successSelector:successSelector failedSelector:failedSelector];
}


- (void)sendAudioCommand:(CommandBase *) command withTarget:(id)target successSelector:(SEL)successSelector failedSelector:(SEL)failedSelector {
    // Try to find suitable clients
    NSMutableArray * connectedClients = [[NSMutableArray alloc] init];
    @synchronized (_carputerDevices)
    {
        for (NSString * key in [_commandClients allKeys])
        {
            CommandClient * client = [_commandClients valueForKey:key];
            CarputerDevice * device = [_carputerDevices valueForKey:key];
            if ((device.audioSupport) && (client.isConnected))
                [connectedClients addObject:client];
        }
    }
    
    // Call failure if no clients found
    if ([connectedClients count] < 1)
    {
        NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorNotConnected userInfo:nil];
        if (!failedSelector)
            [target performSelectorOnMainThread:failedSelector withObject:error waitUntilDone:NO];
        return;
    }
    
    // Call each client with the command
    for (CommandClient * client in connectedClients)
        [client sendCommand:command withTarget:target successSelector:successSelector failedSelector:failedSelector];
    
}

- (BOOL)hasConnectedClients
{
    @synchronized (_carputerDevices)
    {
        for (CommandClient * client in [_commandClients allValues])
            if (client.isConnected)
                return YES;
    }
    return NO;
}


- (void)commandClientConnected:(CommandClient *)client
{
    // Determine device
    CarputerDevice * device = nil;
    for (NSString * deviceKey in _commandClients)
        if ([_commandClients objectForKey:deviceKey] == client)
        {
            device = [_carputerDevices objectForKey:deviceKey];
            break;
        }
    if (!device)
        return;
    
    // If this is an audio client start it probing for audio messages
    if (device.audioSupport)
    {
        [client sendCommand:[[AudioLibrarGetCommand alloc] init] withTarget:self successSelector:@selector(audioLibraryGetSuccess:) failedSelector:@selector(audioLibraryGetFail:)];
    }
}

- (void)commandClient:(CommandClient *)client connectFailedForReason:(NSString *)reason
{
}

- (void)commandClientDisconnected:(CommandClient *)client
{
}


- (void)notificationClientConnected:(NotificationClient *)client
{
}

- (void)notificationClient:(NotificationClient *)client connectFailedForReason:(NSString *)reason
{
}

- (void)notificationClientDisconnected:(NotificationClient *)client {
    
}
- (void)audioLibraryGetSuccess:(CommandClientResponse *)response {
    NSArray * audioFiles = response.response;
    NSLog(@"Received audio library response: %@", audioFiles);
    [[AudioFileFactory applicationInstance] mergeChangesForDevice:response.client.hostname withAudioFiles:audioFiles];
}

- (void)audioLibraryGetFail:(NSArray *)response {
    NSLog(@"Failed to get audio library response: %@", response);
}
@end