#import <UIKit/UIKit.h>

@interface CommandBase : NSObject {
@protected
    ushort _category;
    ushort _opcode;
    BOOL _responseExpected;
    Class _responseJsonType;
}

@property (readonly, assign) BOOL ResponseExpected;
@property (readonly, assign) Class ResponseJsonType;

- (NSData *) jsonRepresentationWithError:(NSError **)error;
- (NSData *) serialiseWithError:(NSError **)error;
- (id) parseResponse:(id)jsonObject withError:(NSError **)parsingError;

@end