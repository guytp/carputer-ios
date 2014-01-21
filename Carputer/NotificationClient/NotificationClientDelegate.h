#import <Foundation/Foundation.h>
@class NotificationClient;

@protocol NotificationClientDelegate <NSObject>

- (void)notificationClientConnected:(NotificationClient *)client;

- (void)notificationClient:(NotificationClient *)client connectFailedForReason:(NSString *)reason;

- (void)notificationClientDisconnected:(NotificationClient *)client;

@end