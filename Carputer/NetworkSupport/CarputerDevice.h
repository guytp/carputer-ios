#import <Foundation/Foundation.h>

@interface CarputerDevice : NSObject {
    @private
    BOOL _audioSupport;
    NSString * _ipAddress;
    NSString * _hostname;
    ushort _commandPort;
    ushort _notificationPort;
    NSDate * _lastUpdated;
}

@property (assign, readonly) BOOL audioSupport;
@property (strong, readonly) NSString * ipAddress;
@property (strong, readonly) NSString * hostname;
@property (assign, readonly) ushort commandPort;
@property (assign, readonly) ushort notificationPort;
@property (strong) NSDate * lastUpdated;

- (id)initWithIpAddress:(NSString *)ipAddress hostname:(NSString *)hostname commandPort:(ushort)commandPort notificationPort:(ushort)notificationPort audioSupport:(BOOL)audioSupport;
@end