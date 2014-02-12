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

- (void)mergeNotificationChangesForDevice:(NSString *)deviceIdentifier added:(NSArray *)addedFiles deleted:(NSArray *)deletedFiles online:(NSArray *)onlineFiles offline:(NSArray *)offlineFiles updated:(NSArray *)updatedFiles;

- (NSArray *)readAllActive;

- (NSArray *)readAllActiveForArtist:(NSString *)artist;

- (AudioFile *)readForId:(NSNumber *)audioFileId forDevice:(NSString *)deviceIdentifier;

- (void)setDeviceOffline:(NSString *)deviceIdentifier;

- (NSArray *)audioFilesWithoutArtwork;

- (void)setArtworkForArtist:(NSString *)artist withFile:(NSString *)file;
- (void)setArtworkForArtist:(NSString *)artist album:(NSString *)album withFile:(NSString *)file;

- (UIImage *)imageForArtist:(NSString *)artist;
- (UIImage *)imageForArtist:(NSString *)artist album:(NSString *)album;
@end