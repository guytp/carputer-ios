#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "NetworkAudioFile.h"

@interface AudioFileFactory : NSObject {
@private
    NSManagedObjectContext * _context;
    NSPersistentStoreCoordinator * _persistentStoreCoordinator;
    NSFetchRequest * _fetchByIdRequest;
    NSMutableArray * _allObjects;
    NSMutableDictionary * _allObjectsById; // Id is an Int~String pair
    NSMutableArray * _artists; // Distinct list of artist names
    NSMutableArray * _lowercaseArtists; // Distinct lowercase version of _artists
    NSMutableArray * _lowercaseAlbums; // Distinct lowercase list of albums in format Artist|~|Album
    NSMutableDictionary * _albumsForArtist; // Keyed by lowercase artist name from _artists.  Contains one or more NSArray objects per album.  The list of albums themselves are actually ordered by the name of the album and the AudioFiles within them are ordered by Track Number then Title.
    NSMutableArray * _artistsWithArtwork; // Array of lowercase artist names that have artwork
    NSMutableArray * _albumsWithArtwork; // Array of Artist|~|Album names that have artwork in lowercase
    NSString * _artistArtworkBasePath;
    NSString * _albumArtworkBasePath;
    NSObject * _syncLocker;
}

+ (AudioFileFactory *) applicationInstance;

- (void)mergeChangesForAudioFiles:(NSArray *)audioFiles;

- (void)mergeNotificationChangesForDevice:(NSString *)deviceIdentifier added:(NSArray *)addedFiles deleted:(NSArray *)deletedFiles online:(NSArray *)onlineFiles offline:(NSArray *)offlineFiles updated:(NSArray *)updatedFiles;

- (NSArray *)availableArtists;

- (NSArray *)availableAlbumsForArtist:(NSString *)artist;

- (NetworkAudioFile *)readForId:(NSNumber *)audioFileId forDevice:(NSString *)device;

- (void)setDeviceOffline:(NSString *)deviceIdentifier;

- (NSArray *)artistsWithoutArtwork;
- (NSDictionary *)albumsWithoutArtwork; // Returns NS Dictionary keyed by artist name and within each key containing an NSArray of all the albums that artist has without artwork available

- (void)setArtworkForArtist:(NSString *)artist data:(NSData *)data;
- (void)setArtworkForArtist:(NSString *)artist album:(NSString *)album data:(NSData *)data;

- (UIImage *)imageForArtist:(NSString *)artist;
- (UIImage *)imageForArtist:(NSString *)artist album:(NSString *)album;
@end