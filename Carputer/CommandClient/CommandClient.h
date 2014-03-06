#import <UIKit/UIKit.h>
#import "CommandBase.h"
#import "CommandClientDelegate.h"
@class StartCommandThreadDefinition;

extern NSString * kCommandClientErrorDomain;
enum CommandClientError {
    CommandClientErrorNotConnected = 0,
    CommandClientErrorCommandNotSupplied = 1,
    CommandClientErrorMissingResponse = 2,
    CommandClientErrorUnexpectedResponse = 3,
    CommandClientErrorResponseParseFail = 4,
    CommandClientErrorSerialiseFail = 5,
    CommandClientErrorRequestTimeout = 6,
    CommandClientErrorRemoteException = 7
    };

@interface CommandClient : NSObject <NSStreamDelegate> {
    @private
    NSString * _hostname;
    ushort _port;
    NSInputStream * _commandInputStream;
    NSOutputStream * _commandOutputStream;
    id _commandLockObject;
    BOOL _isConnected;
    BOOL _isConnecting;
    NSTimer * _statusCheckTimer;
    NSDate * _connectionStartTime;
    StartCommandThreadDefinition * _currentThreadCommandDefinition;
    NSThread * _currentThread;
    NSDate * _currentThreadStartTime;
    NSString * _serialNumber;
}

@property (retain) NSString * hostname;
@property (retain) NSString * serialNumber;
@property (assign) ushort port;
@property (retain) NSObject<CommandClientDelegate> * delegate;
@property (assign, readonly) BOOL isConnected;
@property (assign, readonly) BOOL isConnecting;
@property (strong, atomic) NSDate * lastDataReceived;

- (id)initWithHostname:(NSString *)hostname port:(ushort)port serialNumber:(NSString *)serialNumber;
- (void)connect;
- (void)disconnect;

- (void)sendCommand:(CommandBase *) command withTarget:(id)target successSelector:(SEL)successSelector failedSelector:(SEL)failedSelector;
@end