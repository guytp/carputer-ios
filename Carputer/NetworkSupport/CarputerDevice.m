#import "CarputerDevice.h"

@implementation CarputerDevice
@synthesize ipAddress = _ipAddress;
@synthesize commandPort = _commandPort;
@synthesize notificationPort = _notificationPort;
@synthesize serialNumber = _serialNumber;

- (id)initWithIpAddress:(NSString *)ipAddress commandPort:(ushort)commandPort notificationPort:(ushort)notificationPort {
    // Call to self
    self = [self init];
    if (!self)
        return nil;
    
    // Store values
    _ipAddress = ipAddress;
    _commandPort = commandPort;
    _notificationPort = notificationPort;
    
    // Return self
    return self;
}
@end