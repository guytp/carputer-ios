#import <Foundation/Foundation.h>
#import "GCDAsyncUdpSocket.h"
#import "CommandBase.h"
#import "ClientControllerDelegate.h"
#import "CommandClientDelegate.h"
#import "NotificationClientDelegate.h"
@class NetworkAudioFile;

extern NSString * kClientControllerNewArtworkNotificationName;

@interface ClientController : NSObject <CommandClientDelegate, NotificationClientDelegate> {
    @private
    GCDAsyncUdpSocket * _udpSocket;
    NSMutableDictionary * _carputerDevices;
    NSMutableDictionary * _commandClients;
    NSMutableDictionary * _notificationClients;
    int _lastTotalCount;
    int _lastConnectedCount;
    NSString * _localIp;
    BOOL _awaitingArtworkResponse;
    NSString * _artworkLookupArtist;
    NSString * _artworkLookupAlbum;
}

+ (ClientController *) applicationInstance;


@property (strong) NSObject<ClientControllerDelegate> * delegate;

- (void)sendCommand:(CommandBase *) command withTarget:(id)target successSelector:(SEL)successSelector failedSelector:(SEL)failedSelector;

@end