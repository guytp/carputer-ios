#import "NotificationProcessorBase.h"

@implementation NotificationProcessorBase

@synthesize opCode = _opCode;
@synthesize notificationCode = _notificationCode;


- (id)notificationObjectForJson:(id)jsonObject deviceSerialNumber:(NSString *)deviceSerialNumber {
    return nil;
}
@end