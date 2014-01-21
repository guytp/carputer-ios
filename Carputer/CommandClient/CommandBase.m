#import "CommandBase.h"


@implementation CommandBase
@synthesize ResponseExpected = _responseExpected;
@synthesize ResponseJsonType = _responseJsonType;

- (NSData *) jsonRepresentationWithError:(NSError **)error {
    return nil;
}

- (NSData *)serialiseWithError:(NSError **)error {
    NSData * json = [self jsonRepresentationWithError:error];
    int jsonLength = htonl(!json ? 0 : [json length]);
    NSMutableData * buffer = [[NSMutableData alloc] init];
    ushort category = htons(_category);
    ushort opcode = htons(_opcode);
    [buffer appendBytes:&category length:sizeof(category)];
    [buffer appendBytes:&opcode length:sizeof(opcode)];
    [buffer appendBytes:&jsonLength length:sizeof(jsonLength)];
    [buffer appendData:json];
    return buffer;
}

- (id) parseResponse:(id)jsonObject withError:(NSError **)parsingError {
    return nil;
}
@end