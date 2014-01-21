#import <Foundation/Foundation.h>
@class CommandClient;

@protocol CommandClientDelegate <NSObject>
- (void)commandClientConnected:(CommandClient *)client;

- (void)commandClient:(CommandClient *)client connectFailedForReason:(NSString *)reason;

- (void)commandClientDisconnected:(CommandClient *)client;
@end