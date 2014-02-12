#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface AudioFile : NSManagedObject

@property (nonatomic, retain) NSNumber * id;
@property (nonatomic, retain) NSString * artist;
@property (nonatomic, retain) NSString * album;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSNumber * trackNumber;
@property (nonatomic, retain) NSNumber * duration;
@property (nonatomic, retain) NSString * device;
@property (nonatomic, retain) NSDate * lastSeen;
@property (nonatomic, retain) NSNumber * playCount;
@property (nonatomic, retain) NSNumber * isOnline;

// An empty string indicates that we've checked but there is no file, a null
// value indicates we have not yet checked
@property (nonatomic, retain) NSString * artistArtworkFile;
@property (nonatomic, retain) NSString * albumArtworkFile;

@end