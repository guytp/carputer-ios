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
#import "NetworkAudioFile.h"
#import "AudioLibraryGetCommand.h"
#import "AudioFileFactory.h"
#import "NotificationClient.h"
#import "CommandClientResponse.h"
#import "ArtworkGetCommand.h"
#import "ArtworkGetResponse.h"
#import "EchoCommand.h"

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

- (void)disconnectAllClients {
    @synchronized (_carputerDevices)
    {
        for (CommandClient * commandClient in [_commandClients allValues])
        {
            [[AudioFileFactory applicationInstance] setDeviceOffline:commandClient.serialNumber];
            if (commandClient.isConnected)
                [commandClient disconnect];
        }
        for (NotificationClient * notificationClient in [_notificationClients allValues])
            if (notificationClient.isConnected)
                [notificationClient disconnect];
        
        [_commandClients removeAllObjects];
        [_notificationClients removeAllObjects];
        NSUInteger count = [_carputerDevices count];
        [_carputerDevices removeAllObjects];
        NSLog(@"Removed %lu clients", (unsigned long)count);
    }
}

- (void)statusCheckThread {
    [[NSThread currentThread] setName:@"Client Controller Status Check"];
    BOOL firstLoop = YES;
    while (![NSThread currentThread].isCancelled)
    {
        // Detect whether or not we need to re-bind to the discovery.  This is defined by the local WiFi IP address changing
        NSString * wiFiIpAddress = [self getWiFiIPAddress];
        if (firstLoop)
        {
            firstLoop = NO;
            if (!wiFiIpAddress)
                NSLog(@"Carputer start up but not connected to a network");
        }
        //NSString * broadcastAddress = [self getBroadcastAddress];
        if ((!_localIp && wiFiIpAddress) || (_localIp && !wiFiIpAddress) || (wiFiIpAddress && ![_localIp isEqualToString:wiFiIpAddress]))
        {
            [self disconnectAllClients];
            _localIp = wiFiIpAddress;
            if (!wiFiIpAddress)
                NSLog(@"Disconnected from WiFi");
            else if (![wiFiIpAddress hasPrefix:@"192.168.42."] && ![wiFiIpAddress hasPrefix:@"192.168.43."])
                NSLog(@"Connected to WiFi but not on an appropriate subnet");
            else
            {
                NSLog(@"Connected to WiFi, registering clienxt");
                CarputerDevice * device = [[CarputerDevice alloc] initWithIpAddress:[wiFiIpAddress hasPrefix:@"192.168.42."] ? @"192.168.42.1" : @"192.168.43.3" commandPort:4200 notificationPort:4201];
                @synchronized (_carputerDevices)
                {
                    [_carputerDevices setObject:device forKey:device.ipAddress];
                }
                NSLog(@"Added client for %@", device.ipAddress);
            }
        }
        
        // Reconnect any disconnected command clients
        NSArray * allKeys;
        @synchronized (_carputerDevices)
        {
            allKeys = [_carputerDevices allKeys];
        }
        for (NSString * key in allKeys)
        {
            // Ignore if we're connected
            CommandClient * commandClient = [_commandClients valueForKey:key];
            if ((commandClient.isConnected) || (commandClient.isConnecting))
                continue;
            
            // Request a reconnection if client exists, otherwise create a new client
            CarputerDevice * device;
            @synchronized (_carputerDevices)
            {
                device = [_carputerDevices valueForKey:key];
            }
            if (commandClient)
                NSLog(@"%@:%d:%d has disconnected, reconnecting", device.ipAddress, device.commandPort, device.notificationPort);
            else
            {
                commandClient = [[CommandClient alloc] initWithHostname:device.ipAddress port:device.commandPort serialNumber:device.serialNumber];
                commandClient.delegate = self;
                @synchronized (_carputerDevices)
                {
                    [_commandClients setObject:commandClient forKey:key];
                }
                NSLog(@"%@:%d:%d is new, connecting", device.ipAddress, device.commandPort, device.notificationPort);
            }
            [commandClient connect];
        }
        // Reconnect any disconnected notification clients
        for (NSString * key in allKeys)
        {
            // Ignore if we're connected
            NotificationClient * notificationClient;
            @synchronized (_carputerDevices)
            {
                notificationClient = [_notificationClients valueForKey:key];
            }
            BOOL isTimedOut = [[NSDate date] timeIntervalSinceDate:notificationClient.lastDataReceived] > 3;
            if ((isTimedOut) || ((notificationClient.isConnected) || (notificationClient.isConnecting)))
                continue;
            
            // Disconnect if already connected
            if ((notificationClient.isConnected) || (notificationClient.isConnecting))
                [notificationClient disconnect];
            
            // Request a reconnection if client exists, otherwise create a new client
            CarputerDevice * device = [_carputerDevices valueForKey:key];
            if (notificationClient)
                NSLog(@"%@:%d:%d (notification) has disconnected, reconnecting", device.ipAddress, device.commandPort, device.notificationPort);
            else
            {
                notificationClient = [[NotificationClient alloc] initWithHostname:device.ipAddress port:device.notificationPort serialNumber:device.serialNumber];
                notificationClient.delegate = self;
                @synchronized (_carputerDevices)
                {
                    [_notificationClients setObject:notificationClient forKey:key];
                }
                NSLog(@"%@:%d:%d (notification) is new, connecting", device.ipAddress, device.commandPort, device.notificationPort);
            }
            [notificationClient connect];
        }
        
        // Fire an echo off to everythng to test f we're stll onlne
        NSArray * allCommandClients;
        int totalCount;
        @synchronized (_carputerDevices)
        {
            allCommandClients = [_commandClients allValues];
            totalCount = (int)[_carputerDevices count];
        }
        for (CommandClient * commandClient in allCommandClients)
            if (commandClient.isConnected)
                [commandClient sendCommand:[[EchoCommand alloc] initWithMessage:@""] withTarget:nil successSelector:nil failedSelector:nil];
        
        
        // Get total counts
        int connectedCount = 0;
        for (CommandClient * commandClient in allCommandClients)
            if (commandClient.isConnected)
                connectedCount++;
        if ((self.delegate) && ((connectedCount != _lastConnectedCount) || (totalCount != _lastTotalCount)))
            [self.delegate clientController:self totalClients:totalCount connectedClients:connectedCount];
        _lastConnectedCount = connectedCount;
        _lastTotalCount = totalCount;
        
        // Wait to re-loop
        [NSThread sleepForTimeInterval:1.0];
    }
}


- (void)sendCommand:(CommandBase *) command withTarget:(id)target successSelector:(SEL)successSelector failedSelector:(SEL)failedSelector {
    // Try to find suitable clients
    NSMutableArray * connectedClients = [[NSMutableArray alloc] init];
    NSArray * commandClients;
    @synchronized (_carputerDevices)
    {
        commandClients = [_commandClients allValues];
    }
    for (CommandClient * client in commandClients)
        if (client.isConnected)
            [connectedClients addObject:client];
    
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
    [client sendCommand:[[AudioLibrarGetCommand alloc] init] withTarget:self successSelector:@selector(audioLibraryGetSuccess:) failedSelector:@selector(audioLibraryGetFail:)];
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
    for (NetworkAudioFile * file in audioFiles)
        file.device = response.client.serialNumber;
    [[AudioFileFactory applicationInstance] mergeChangesForAudioFiles:audioFiles];
}

- (void)audioLibraryGetFail:(NSArray *)response {
    NSLog(@"Failed to get audio library response: %@", response);
}


- (NSString*)getWiFiIPAddress
{
    
    BOOL success;
    struct ifaddrs * addrs;
    const struct ifaddrs * cursor;
    
    NSString * devIp = nil;
    NSString * prodIp = nil;
    
    success = getifaddrs(&addrs) == 0;
    if (success) {
        cursor = addrs;
        while (cursor != NULL) {
            if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0) // this second test keeps from picking up the loopback address
            {
                NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
                NSString * ip = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
                if ([name isEqualToString:@"en0"])
                    prodIp = ip;
                else if ([ip hasPrefix:@"192.168.43."])
                    devIp = ip;
            }
            
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return prodIp ? prodIp : devIp;
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
        NSArray * artistsWithoutArtwork = [[AudioFileFactory applicationInstance] artistsWithoutArtwork];
        NSDictionary * albumsWithoutArtwork = [[AudioFileFactory applicationInstance] albumsWithoutArtwork];
        
        if (albumsWithoutArtwork.count + artistsWithoutArtwork.count == 0)
        {
            [NSThread sleepForTimeInterval:5];
            continue;
        }
        
        // First process artists
        for (NSString * artist in artistsWithoutArtwork)
        {
            ArtworkGetCommand * command = [[ArtworkGetCommand alloc] initWithArtist:artist];
            _awaitingArtworkResponse = YES;
            _artworkLookupArtist = artist;
            [self sendCommand:command withTarget:self successSelector:@selector(audioArtworkResponseSuccess:) failedSelector:@selector(audioArtworkResponseFail:)];
            NSDate * endDate = [NSDate dateWithTimeIntervalSinceNow:5];
            while (_awaitingArtworkResponse && [[NSDate date] timeIntervalSinceDate:endDate] < 5)
                [NSThread sleepForTimeInterval:0.1];
            _artworkLookupArtist = nil;
        }
        
        // Now process albums
        for (NSString * artist in [albumsWithoutArtwork allKeys])
        {
            NSArray * albums = [albumsWithoutArtwork objectForKey:artist];
            for (NSString * album in albums)
            {
                ArtworkGetCommand * command = [[ArtworkGetCommand alloc] initWithArtist:artist album:album getArtistImage:NO];
                _awaitingArtworkResponse = YES;
                _artworkLookupArtist = artist;
                _artworkLookupAlbum = album;
                [self sendCommand:command withTarget:self successSelector:@selector(audioArtworkResponseSuccess:) failedSelector:@selector(audioArtworkResponseFail:)];
                NSDate * endDate = [NSDate dateWithTimeIntervalSinceNow:5];
                while (_awaitingArtworkResponse && [[NSDate date] timeIntervalSinceDate:endDate] < 5)
                    [NSThread sleepForTimeInterval:0.1];
                _artworkLookupArtist = nil;
                _artworkLookupAlbum = nil;
            }
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
    
    // Skip if no images available
    if ((!artworkResponse.artistImageAvailable) && (!artworkResponse.albumImageAvailable))
    {
        _awaitingArtworkResponse = NO;
        return;
    }
    
    // Save the artist image to disk if requested and provided and update the object accordingly
    if ((artworkResponse.requestedGetArtistImage) && ([artworkResponse.artistImageAvailable boolValue]))
        [[AudioFileFactory applicationInstance] setArtworkForArtist:_artworkLookupArtist data:artworkResponse.artistImageData];
    
    // Now do the same for the album image
    if ((artworkResponse.requestedGetAlbumImage) && ([artworkResponse.albumImageAvailable boolValue]))
        [[AudioFileFactory applicationInstance] setArtworkForArtist:_artworkLookupArtist album:_artworkLookupAlbum data:artworkResponse.albumImageData];
    
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