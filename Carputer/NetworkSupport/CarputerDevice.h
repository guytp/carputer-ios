#import <Foundation/Foundation.h>

@interface CarputerDevice : NSObject {
    @private
    NSString * _ipAddress;
    ushort _commandPort;
    ushort _notificationPort;
    NSString * _serialNumber;
}

@property (strong, readonly) NSString * ipAddress;
@property (assign, readonly) ushort commandPort;
@property (assign, readonly) ushort notificationPort;
@property (strong) NSString * serialNumber;

- (id)initWithIpAddress:(NSString *)ipAddress commandPort:(ushort)commandPort notificationPort:(ushort)notificationPort;
@end