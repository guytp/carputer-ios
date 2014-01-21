#import "PlaylistJumpCommand.h"

@implementation PlaylistJumpCommand
@synthesize position = _position;

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Store values
    _category = 0x01;
    _opcode = 0x02;
    _responseExpected = NO;
    
    // Return self
    return self;
}

- (id)initWithPosition:(int)position
{
    // Call to self
    self = [self init];
    
    // Store message
    self.position = position;
    
    // Return self
    return self;
}

- (NSData *)jsonRepresentationWithError:(NSError **)error {
    return [[NSString stringWithFormat:@"%d", _position] dataUsingEncoding:NSUTF8StringEncoding];
}
@end