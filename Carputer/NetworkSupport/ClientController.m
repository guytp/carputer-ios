#include <ifaddrs.h>
#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <net/if.h>
#include <net/if_dl.h>
#include <arpa/inet.h>
#include <ifaddrs.h>
#if ! defined(IFT_ETHER)
#define IFT_ETHER 0x6/* Ethernet CSMACD */
#endif
#import "ClientController.h"
#import "NSDictionary+Dictionary_ContainsKey.h"
#import "CarputerDevice.h"
#import "CommandClient.h"
#import "AudioFile.h"
#import "AudioLibraryGetCommand.h"
#import "AudioFileFactory.h"
#import "NotificationClient.h"
#import "CommandClientResponse.h"
#import "ArtworkGetCommand.h"
#import "ArtworkGetResponse.h"

NSString * kClientControllerNewArtworkNotificationName = @"ClientControllerNewArtworkNotificationName";

@interface ClientController()
- (NSString*)getWiFiIPAddress;
- (NSString *) getBroadcastAddress;
@end


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
    _udpSocket = nil;
    _localIp = nil;
    
    // Start status check thread
    [NSThread detachNewThreadSelector:@selector(statusCheckThread) toTarget:self withObject:nil];
    
    // Start audio artwork update thread
    [NSThread detachNewThreadSelector:@selector(audioArtworkUpdateThread) toTarget:self withObject:nil];
    
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
    NSString * serialNumber = [jsonObject valueForKey:@"SerialNumber"];
    
    // If core values are missing return
    if ((!hostname) || (notificationPort < 1) || (commandPort < 1))
    {
        NSLog(@"Discovery packet missing core information, discarding");
        return;
    }
    NSString * ipAddress = [GCDAsyncUdpSocket hostFromAddress:address];
    
    // Check if we have this server already, if not then add a new server to the list, otherwise
    // update its last seen time
    if ([_carputerDevices containsKey:serialNumber])
    {
        CarputerDevice * device = [_carputerDevices valueForKey:serialNumber];
        device.lastUpdated = [NSDate date];
    }
    else
    {
        CarputerDevice * device = [[CarputerDevice alloc] initWithIpAddress:ipAddress hostname:hostname commandPort:commandPort notificationPort:notificationPort audioSupport:audioSupport serialNumber:serialNumber];
        @synchronized (_carputerDevices)
        {
            [_carputerDevices setObject:device forKey:serialNumber];
        }
        NSLog(@"%@ discovered and added to our list", serialNumber);
    }
}

- (void)statusCheckThread {
    [[NSThread currentThread] setName:@"Client Controller Status Check"];
    while (![NSThread currentThread].isCancelled)
    {
        // Detect whether or not we need to re-bind to the discovery.  This is defined by the local WiFi
        // IP address changing
        // Determine
        NSString * wiFiIpAddress = [self getWiFiIPAddress];
        NSString * broadcastAddress = [self getBroadcastAddress];
        if ((!_localIp && wiFiIpAddress) || (_localIp && !wiFiIpAddress) || (wiFiIpAddress && ![_localIp isEqualToString:wiFiIpAddress]))
        {
            NSError *error = nil;
            
            // If socket already exists kill it, otherwise re-create
            NSLog(@"WiFi status change");
            if (_udpSocket)
            {
                [_udpSocket close];
                _udpSocket = nil;
            }
            if (!wiFiIpAddress)
            {
                NSLog(@"Disconnected from WiFi, terminating discovery");
                _localIp = nil;
            }
            else
            {
                NSLog(@"Connected to WiFi, starting discovery");
                _udpSocket = [[GCDAsyncUdpSocket alloc] initWithDelegate:self delegateQueue:dispatch_get_main_queue()];
                
                if (![_udpSocket bindToPort:4200 error:&error])
                    NSLog(@"Error binding to discovery port: %@", error);
                else
                {
                    if (![_udpSocket beginReceiving:&error])
                        NSLog(@"Error starting receiving from multicast discovery: %@", error);
                    else
                    {
                        NSLog(@"Multicast discovery started");
                        _localIp = wiFiIpAddress;
                    }
                }
            }
        }
    
        
        // Remove any timed out devices
        @synchronized (_carputerDevices)
        {
            NSArray * allKeys = [_carputerDevices allKeys];
            for (NSString * key in allKeys)
            {
                // Ignore if we've seen it recently via broadcast or data receipt
                CarputerDevice * device = [_carputerDevices valueForKey:key];
                NotificationClient * notificationClient = [_notificationClients valueForKey:key];
                CommandClient * commandClient = [_commandClients valueForKey:key];
                if (([device.lastUpdated timeIntervalSinceNow] > -10) && ([notificationClient.lastDataReceived timeIntervalSinceNow] > -10) && ([commandClient.lastDataReceived timeIntervalSinceNow] > -10))
                    continue;
                
                // Set all of the audio files offline for this device
                [[AudioFileFactory applicationInstance] setDeviceOffline:commandClient.serialNumber];
                
                // Disconnect if required
                if ((commandClient) && (commandClient.isConnected))
                    [commandClient disconnect];
                if ((notificationClient) && (notificationClient.isConnected))
                    [notificationClient disconnect];
                
                // Remove from list
                NSLog(@"%@:%@:%d:%d has timed out, removing from our known devices", device.ipAddress, device.hostname, device.commandPort, device.notificationPort);
                [_carputerDevices removeObjectForKey:key];
                [_notificationClients removeObjectForKey:key];
                [_commandClients removeObjectForKey:key];
                
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
                    commandClient = [[CommandClient alloc] initWithHostname:device.ipAddress port:device.commandPort serialNumber:device.serialNumber];
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
                    notificationClient = [[NotificationClient alloc] initWithHostname:device.ipAddress port:device.notificationPort serialNumber:device.serialNumber];
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
        [NSThread sleepForTimeInterval:0.5];
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
    [[AudioFileFactory applicationInstance] mergeChangesForDevice:response.client.serialNumber withAudioFiles:audioFiles];
}

- (void)audioLibraryGetFail:(NSArray *)response {
    NSLog(@"Failed to get audio library response: %@", response);
}


- (NSString*)getWiFiIPAddress
{
    
    BOOL success;
    struct ifaddrs * addrs;
    const struct ifaddrs * cursor;
    
    success = getifaddrs(&addrs) == 0;
    if (success) {
        cursor = addrs;
        while (cursor != NULL) {
            if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0) // this second test keeps from picking up the loopback address
            {
                NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
                if ([name isEqualToString:@"en0"]) { // found the WiFi adapter
                    return [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
                }
            }
            
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return NULL;
}


- (NSString *) getBroadcastAddress {
    NSString * broadcastAddr = nil;
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    
    if (success == 0)
    {
        temp_addr = interfaces;
        
        while(temp_addr != NULL)
        {
            // check if interface is en0 which is the wifi connection on the iPhone
            if(temp_addr->ifa_addr->sa_family == AF_INET)
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                    broadcastAddr = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_dstaddr)->sin_addr)];
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    freeifaddrs(interfaces);
    return broadcastAddr;
}


- (void)audioArtworkUpdateThread {
    while (YES)
    {
        // Try to get a file that we need artwork for, if we can't find one then we sit and
        // wait for the next try
        NSArray * files = [[AudioFileFactory applicationInstance] audioFilesWithoutArtwork];
        if (!files || files.count < 1)
        {
            [NSThread sleepForTimeInterval:5];
            continue;
        }
        
        NSMutableArray * processedArtists = [NSMutableArray array];
        NSMutableArray * processedAlbums = [NSMutableArray array];
        for (AudioFile * file in files)
        {
            // Determine what we need to parse from this item.  If in this loop we've already
            // got the data since we read from database then skip it
            BOOL getArtistImage = !file.artistArtworkFile;
            BOOL getAlbumImage = !file.artistArtworkFile;
            if (getArtistImage && [processedArtists containsObject:file.artist])
                getArtistImage = NO;
            if (getAlbumImage && [processedAlbums containsObject:[NSString stringWithFormat:@"%@||%@", file.artist, file.album]])
                getAlbumImage = NO;
            if ((!getArtistImage) && (!getAlbumImage))
                continue;
            
            // Add this item to the processed lists so we don't re-try this same loop
            if (getArtistImage)
                [processedArtists addObject:file.artist];
            if (getAlbumImage)
                [processedAlbums addObject:[NSString stringWithFormat:@"%@||%@", file.artist, file.album]];
            
            // Determine the correct client
            if (![_carputerDevices containsKey:file.device])
                continue;
            CommandClient * client;
            @synchronized (_carputerDevices)
            {
                client = [_commandClients valueForKey:file.device];
            }
            
            // Put together a request to get the album/artist (or both) artwork for this file
            // and send to the appropriate command client
            ArtworkGetCommand * command = nil;
            if (!getAlbumImage)
                command = [[ArtworkGetCommand alloc] initWithArtist:file.artist];
            else
                command = [[ArtworkGetCommand alloc] initWithArtist:file.artist album:file.album getArtistImage:getArtistImage];
            
            // Execute the command and await completion
            _awaitingArtworkResponse = YES;
            _artworkAudioFile = file;
            [client sendCommand:command withTarget:self successSelector:@selector(audioArtworkResponseSuccess:) failedSelector:@selector(audioArtworkResponseFail:)];
            NSDate * endDate = [NSDate dateWithTimeIntervalSinceNow:5];
            while (_awaitingArtworkResponse && [[NSDate date] timeIntervalSinceDate:endDate] < 5)
                [NSThread sleepForTimeInterval:0.1];
            _artworkAudioFile = nil;
        }
        
        // Wait another minute before we try again
        NSDate * endLoop = [NSDate dateWithTimeIntervalSinceNow:60];
        while ([[NSDate date] timeIntervalSinceDate:endLoop] < 5)
            [NSThread sleepForTimeInterval:0.5];
    }
}

- (void)audioArtworkResponseSuccess:(CommandClientResponse *)response {
    // Log the success
    ArtworkGetResponse * artworkResponse = response.response;
    
    // Get path data
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * artworkDirectory = [[paths lastObject] stringByAppendingPathComponent:@"artwork"];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    BOOL isDir = YES;
    BOOL isDirExists = [fileManager fileExistsAtPath:artworkDirectory isDirectory:&isDir];
    if (!isDirExists) [fileManager createDirectoryAtPath:artworkDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Skip if no images available
    if ((!artworkResponse.artistImageAvailable) && (!artworkResponse.albumImageAvailable))
    {
        _awaitingArtworkResponse = NO;
        return;
    }
    
    // Save the artist image to disk if requested and provided and update the object accordingly
    if ((artworkResponse.requestedGetArtistImage) && ([artworkResponse.artistImageAvailable boolValue]))
    {
        NSString * filePath = [artworkDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"artist%d.png", [_artworkAudioFile.id intValue]]];
        [artworkResponse.artistImageData writeToFile:filePath atomically:NO];
        [[AudioFileFactory applicationInstance] setArtworkForArtist:_artworkAudioFile.artist withFile:filePath];
    }
    
    // Now do the same for the album image
    if ((artworkResponse.requestedGetAlbumImage) && ([artworkResponse.albumImageAvailable boolValue]))
    {
        NSString * filePath = [artworkDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"album%d.png", [_artworkAudioFile.id intValue]]];
        [artworkResponse.albumImageData writeToFile:filePath atomically:NO];
        [[AudioFileFactory applicationInstance] setArtworkForArtist:_artworkAudioFile.artist album:_artworkAudioFile.album withFile:filePath];
    }
    
    // Send a notification to any clients that may be listening
    [[NSNotificationCenter defaultCenter] postNotificationName:kClientControllerNewArtworkNotificationName object:artworkResponse];
    
    // Mark as as having completed
    _awaitingArtworkResponse = NO;
}

- (void)audioArtworkResponseFail:(NSError *)error {
    // Log the failure
    NSLog(@"Error getting audio artwork %@", error);
    
    // Mark uas as having completed
    _awaitingArtworkResponse = NO;
}
@end