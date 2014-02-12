#import <Foundation/Foundation.h>

@interface NetworkAudioFile : NSObject

@property (nonatomic, strong) NSNumber * audioFileId;
@property (nonatomic, strong) NSString * artist;
@property (nonatomic, strong) NSString * album;
@property (nonatomic, strong) NSString * title;
@property (nonatomic, strong) NSNumber * trackNumber;
@property (nonatomic, strong) NSNumber * duration;

- (id)initWithJsonObject:(NSDictionary *)audioFileDictionary;
@end