#import "CommandBase.h"

@interface PlaylistJumpCommand : CommandBase

@property (assign, nonatomic) int position;

- (id)initWithPosition:(int)position;
@end