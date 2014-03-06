#import <Foundation/Foundation.h>

@interface NetworkAudioFile : NSObject

@property (nonatomic, strong) NSNumber * audioFileId;
@property (nonatomic, strong) NSString * artist;
@property (nonatomic, strong) NSString * album;
@property (nonatomic, strong) NSString * title;
@property (nonatomic, strong) NSNumber * trackNumber;
@property (nonatomic, strong) NSNumber * duration;
@property (nonatomic, retain) NSString * device;
@property (nonatomic, retain) NSDate * lastSeen;
@property (nonatomic, retain) NSNumber * playCount;
@property (nonatomic, retain) NSNumber * isOnline;
@property (readonly) NSString * primaryKey;

// An empty string indicates that we've checked but there is no file, a null
// value indicates we have not yet checked
@property (nonatomic, retain) NSString * artistArtworkFile;
@property (nonatomic, retain) NSString * albumArtworkFile;

- (id)initWithJsonObject:(NSDictionary *)audioFileDictionary;

- (NSComparisonResult)compareByNumber:(NetworkAudioFile *)otherObject;
@end