#import "CommandBase.h"

@interface TrackJumpCommand : CommandBase

@property (assign, nonatomic) int offset;

- (id)initWithOffset:(int)offset;
@end