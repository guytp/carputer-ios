#import "CommandBase.h"

@interface PlaylistQueueCommand : CommandBase
@property (nonatomic, strong) NSArray * audioFileIds;
@property (nonatomic, assign) BOOL replaceCurrentQueue;

- (id)initWithAudioFileIds:(NSArray *)audioFileIds replaceCurrentQueue:(BOOL)replaceCurrentQueue;
@end