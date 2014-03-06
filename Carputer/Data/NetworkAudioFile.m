#import "NetworkAudioFile.h"

@implementation NetworkAudioFile

@synthesize audioFileId;
@synthesize artist;
@synthesize album;
@synthesize title;
@synthesize trackNumber;
@synthesize duration;
@synthesize device;
@synthesize lastSeen;
@synthesize playCount;
@synthesize isOnline;

// An empty string indicates that we've checked but there is no file, a null
// value indicates we have not yet checked
@synthesize artistArtworkFile;
@synthesize albumArtworkFile;


- (id)initWithJsonObject:(NSDictionary *)audioFileDictionary {
    // Call to self
    self = [self init];
    if (!self)
        return nil;
    
    // Store properties
    self.audioFileId = [audioFileDictionary objectForKey:@"AudioFileId"];
    self.artist = [audioFileDictionary objectForKey:@"Artist"];
    if ([self.artist isKindOfClass:[NSNull class]])
        self.artist = nil;
    self.album = [audioFileDictionary objectForKey:@"Album"];
    if ([self.album isKindOfClass:[NSNull class]])
        self.album = nil;
    self.title = [audioFileDictionary objectForKey:@"Title"];
    if ([self.title isKindOfClass:[NSNull class]])
        self.title = nil;
    self.trackNumber = [audioFileDictionary objectForKey:@"TrackNumber"];
    if ([self.trackNumber isKindOfClass:[NSNull class]])
        self.trackNumber = nil;
    self.duration = [audioFileDictionary objectForKey:@"DurationSeconds"];
    if ([self.duration isKindOfClass:[NSNull class]])
        self.duration = nil;
    
    // Return self
    return self;
}


- (NSString *)primaryKey {
    return [NSString stringWithFormat:@"%@~%@", self.audioFileId, self.device];
}


- (NSComparisonResult)compareByNumber:(NetworkAudioFile *)otherObject {
    NSNumber * thisTrackNumber = self.trackNumber;
    NSNumber * otherTrackNumber = otherObject.trackNumber;
    NSComparisonResult result;
    if(!thisTrackNumber && !otherTrackNumber)
        result = NSOrderedSame;
    else if (!thisTrackNumber)
        result = NSOrderedAscending;
    else if (!otherTrackNumber)
        result = NSOrderedDescending;
    else
        result = [self.trackNumber compare:otherObject.trackNumber];
    if (result == NSOrderedSame)
        result = [self.title compare:otherObject.title];
    return result;
}
@end