#import <Foundation/Foundation.h>

@interface NotificationProcessorBase : NSObject {
    @protected
    int _opCode;
    int _notificationCode;
}

@property (readonly, assign, nonatomic) int opCode;
@property (readonly, assign, nonatomic) int notificationCode;

- (id)notificationObjectForJson:(id)jsonObject deviceSerialNumber:(NSString *)deviceSerialNumber;
@end