#import <Foundation/Foundation.h>
@class CommandClient;

@interface CommandClientResponse : NSObject {
    @private
    id _response;
    CommandClient * _client;
}

@property (strong, readonly) id response;
@property (strong, readonly) CommandClient * client;

- (id)initWithClient:(CommandClient *)client response:(id)response;
@end