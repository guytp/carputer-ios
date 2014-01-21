#import <Foundation/Foundation.h>
@class CommandBase;
@class CommandClient;

@interface StartCommandThreadDefinition : NSObject

@property (retain) CommandBase * command;
@property (retain) id target;
@property (assign) SEL successSelector;
@property (assign) SEL failedSelector;

@end