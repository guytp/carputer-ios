#import "CarputerDevice.h"

@implementation CarputerDevice
@synthesize audioSupport = _audioSupport;
@synthesize ipAddress = _ipAddress;
@synthesize hostname = _hostname;
@synthesize commandPort = _commandPort;
@synthesize notificationPort = _notificationPort;
@synthesize lastUpdated = _lastUpdated;
@synthesize serialNumber = _serialNumber;

- (id)initWithIpAddress:(NSString *)ipAddress hostname:(NSString *)hostname commandPort:(ushort)commandPort notificationPort:(ushort)notificationPort audioSupport:(BOOL)audioSupport serialNumber:(NSString *)serialNumber {
    // Call to self
    self = [self init];
    if (!self)
        return nil;
    
    // Store values
    _audioSupport = audioSupport;
    _ipAddress = ipAddress;
    _hostname = hostname;
    _commandPort = commandPort;
    _notificationPort = notificationPort;
    _lastUpdated = [NSDate date];
    _serialNumber = serialNumber;
    
    // Return self
    return self;
}
@end