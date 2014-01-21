#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "AudioFile.h"

@interface AudioFileFactory : NSObject {
@private
    NSManagedObjectContext * _context;
    NSPersistentStoreCoordinator * _persistentStoreCoordinator;
}

+ (AudioFileFactory *) applicationInstance;

- (void)mergeChangesForDevice:(NSString *)deviceIdentifier withAudioFiles:(NSArray *)audioFiles;

- (NSArray *)readAllActive;

- (NSArray *)readAllActiveForArtist:(NSString *)artist;

- (AudioFile *)readForId:(NSNumber *)audioFileId forDevice:(NSString *)deviceIdentifier;
@end