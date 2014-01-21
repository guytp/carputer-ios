#import "ToggleRepeatCommand.h"

@implementation ToggleRepeatCommand

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Store values
    _category = 0x01;
    _opcode = 0x08;
    _responseExpected = NO;
    
    // Return self
    return self;
}

@end