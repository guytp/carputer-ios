#import "CommandClientResponse.h"

@implementation CommandClientResponse

@synthesize response = _response;
@synthesize client = _client;

- (id)initWithClient:(CommandClient *)client response:(id)response {
    // Call to self
    self = [self init];
    if (!self)
        return nil;
    
    // Store values
    _client = client;
    _response = response;
    
    // Return self
    return self;
}
@end