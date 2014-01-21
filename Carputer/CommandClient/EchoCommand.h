#import "CommandBase.h"

@interface EchoCommand : CommandBase

@property (nonatomic, retain) NSString * message;

- (id)initWithMessage:(NSString *)message;
@end