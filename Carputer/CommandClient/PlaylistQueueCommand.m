#import "PlaylistQueueCommand.h"

@implementation PlaylistQueueCommand
@synthesize audioFileIds = _audioFileIds;
@synthesize replaceCurrentQueue = _replaceCurrentQueue;

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Store values
    _category = 0x01;
    _opcode = 0x01;
    _responseExpected = NO;
    
    // Return self
    return self;
}

- (id)initWithAudioFileIds:(NSArray *)audioFileIds replaceCurrentQueue:(BOOL)replaceCurrentQueue {
    // Call to self
    self = [self init];
    
    // Store message
    self.audioFileIds = audioFileIds;
    self.replaceCurrentQueue = replaceCurrentQueue;
    
    // Return self
    return self;
}

- (NSData *)jsonRepresentationWithError:(NSError **)error {
    NSMutableDictionary * jsonObject = [[NSMutableDictionary alloc] init];
    [jsonObject setObject:self.audioFileIds forKey:@"AudioFileIds"];
    [jsonObject setObject:[NSNumber numberWithBool:self.replaceCurrentQueue] forKey:@"ReplaceCurrentQueue"];
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:kNilOptions error:error];
}
@end