#import "EchoCommand.h"
#import "NSDictionary+Dictionary_ContainsKey.h"
#import "CommandClient.h"

@implementation EchoCommand

@synthesize message = _message;

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Store values
    _category = 0xFF;
    _opcode = 0x00;
    _responseExpected = YES;
    _responseJsonType = [NSDictionary class];
    
    // Return self
    return self;
}

- (id)initWithMessage:(NSString *)message {
    // Call to self
    self = [self init];
    
    // Store message
    self.message = message;
    
    // Return self
    return self;
}

- (NSData *) jsonRepresentationWithError:(NSError **)error {
    NSMutableDictionary * jsonObject = [[NSMutableDictionary alloc] init];
    [jsonObject setObject:self.message forKey:@"Message"];
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:kNilOptions error:error];
}

- (id) parseResponse:(id)jsonObject withError:(NSError **)parsingError {
    NSDictionary * jsonDictionary = (NSDictionary *)jsonObject;
    if (![jsonDictionary containsKey:@"Message"])
    {
        NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorResponseParseFail userInfo:nil];
        *parsingError = error;
        return nil;
    }
    return [jsonDictionary valueForKey:@"Message"];
}
@end