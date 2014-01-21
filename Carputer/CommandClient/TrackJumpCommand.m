#import "TrackJumpCommand.h"

@implementation TrackJumpCommand
@synthesize offset = _offset;

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Store values
    _category = 0x01;
    _opcode = 0x04;
    _responseExpected = NO;
    
    // Return self
    return self;
}

- (id)initWithOffset:(int)offset
{
    // Call to self
    self = [self init];
    
    // Store message
    self.offset = offset;
    
    // Return self
    return self;
}

- (NSData *)jsonRepresentationWithError:(NSError **)error {
    return [[NSString stringWithFormat:@"%d", _offset] dataUsingEncoding:NSUTF8StringEncoding];
}
@end