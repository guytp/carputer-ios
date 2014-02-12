#import <Foundation/Foundation.h>
#import "NotificationClientDelegate.h"

extern NSString * kNotificationClientNotificationName;

@interface NotificationClient : NSObject <NSStreamDelegate> {
@private
    NSString * _hostname;
    ushort _port;
    NSInputStream * _inputStream;
    NSOutputStream * _outputStream;
    BOOL _isConnected;
    BOOL _isConnecting;
    NSTimer * _statusCheckTimer;
    NSDate * _connectionStartTime;
    NSMutableArray * _processors;
    NSThread * _processingThread;
    NSString * _serialNumber;
}

@property (retain) NSString * hostname;
@property (assign) ushort port;
@property (retain) NSObject<NotificationClientDelegate> * delegate;
@property (assign, readonly) BOOL isConnected;
@property (assign, readonly) BOOL isConnecting;
@property (strong, atomic) NSDate * lastDataReceived;

- (id)initWithHostname:(NSString *)hostname port:(ushort)port serialNumber:(NSString *)serialNumber;
- (void)connect;
- (void)disconnect;
+ (id)lastNotificationOfType:(NSString *)type;

@end