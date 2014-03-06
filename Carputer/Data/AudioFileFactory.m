#import "AudioFileFactory.h"
#import "NSDictionary+Dictionary_ContainsKey.h"
#import "NSMutableArray+NSMutableArray_AlbumSort.h"

@interface AudioFileFactory()
- (void)setAllOfflineAndRemoveOld;
- (void)addNewFile:(NetworkAudioFile *)file;
- (void)removeFile:(NetworkAudioFile *)file;
- (BOOL)artworkExistsForArtist:(NSString *)artist;
- (BOOL)artworkExistsForArtist:(NSString *)artist album:(NSString *)album;
- (NSString *)artworkFilenameForArtist:(NSString *)artist;
- (NSString *)artworkFilenameForArtist:(NSString *)artist album:(NSString *)album;
- (NSString *)artworkPathForArtist:(NSString *)artist;
- (NSString *)artworkPathForArtist:(NSString *)artist album:(NSString *)album;
- (NetworkAudioFile *)mergeAudioFile:(NetworkAudioFile *)networkAudioFile withExistingObjects:(NSDictionary *)allExistingObjects withNewObjectArray:(NSMutableArray *)newObjects;
@end

@implementation AudioFileFactory
#pragma mark -
#pragma mark Initialisation
static AudioFileFactory * _applicationInstance;

+ (AudioFileFactory *)applicationInstance
{
    // Create the application instance if it doesn't exist
    if (!_applicationInstance)
    {
        // Create new instance
        AudioFileFactory * applicationInstance = [[AudioFileFactory alloc] init];
        
        // As we're starting up first step is to update the data source so that isOnline is false
        // and that anything not seen in 28 days is deleted
        [_applicationInstance setAllOfflineAndRemoveOld];
        
        // Store as application instance now it is initialised
        _applicationInstance = applicationInstance;
    }
    return _applicationInstance;
}

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Setup our mapping objects
    _allObjects = [NSMutableArray array];
    _allObjectsById = [NSMutableDictionary dictionary];
    _artists = [NSMutableArray array];
    _albumsForArtist = [NSMutableDictionary dictionary];
    _lowercaseArtists = [NSMutableArray array];
    _artistsWithArtwork = [NSMutableArray array];
    _albumsWithArtwork = [NSMutableArray array];
    _lowercaseAlbums = [NSMutableArray array];
    _syncLocker = [[NSObject alloc] init];
    
    // Determine file storage for artwork
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * artworkDirectory = [[paths lastObject] stringByAppendingPathComponent:@"artwork"];
    _artistArtworkBasePath = [artworkDirectory stringByAppendingPathComponent:@"artists"];
    _albumArtworkBasePath = [artworkDirectory stringByAppendingPathComponent:@"albums"];
    NSFileManager * fileManager = [NSFileManager defaultManager];
    BOOL isDir = YES;
    BOOL isDirExists = [fileManager fileExistsAtPath:_artistArtworkBasePath isDirectory:&isDir];
    if (!isDirExists) [fileManager createDirectoryAtPath:_artistArtworkBasePath withIntermediateDirectories:YES attributes:nil error:nil];
    isDirExists = [fileManager fileExistsAtPath:_albumArtworkBasePath isDirectory:&isDir];
    if (!isDirExists) [fileManager createDirectoryAtPath:_albumArtworkBasePath withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Return self
    return self;
}


#pragma mark -
#pragma mark Merging
- (void)addNewFile:(NetworkAudioFile *)file {
    if ([self readForId:file.audioFileId forDevice:file.device])
    {
//        NSLog(@"Oops already exists!");
    }
    [_allObjects addObject:file];
    [_allObjectsById setObject:file forKey:file.primaryKey];
    NSString * lowercaseArtist = [file.artist lowercaseString];
    if (![_lowercaseArtists containsObject:lowercaseArtist])
    {
        [_lowercaseArtists addObject:lowercaseArtist];
        [_artists addObject:file.artist];
        [_artists sortUsingSelector:@selector(caseInsensitiveCompare:)];
        [_albumsForArtist setObject:[NSMutableArray array] forKey:lowercaseArtist];
        if ((![_artistsWithArtwork containsObject:lowercaseArtist]) && ([self artworkExistsForArtist:file.artist]))
            [_artistsWithArtwork addObject:lowercaseArtist];
    }
    NSMutableArray * albumsForArtist = [_albumsForArtist objectForKey:lowercaseArtist];
    NSMutableArray * thisAlbum = nil;
    NSString * lowercaseAlbum = [file.album lowercaseString];
    for (NSMutableArray * album in albumsForArtist)
    {
        NetworkAudioFile * firstTrack = [album objectAtIndex:0];
        if ([[firstTrack.album lowercaseString] isEqualToString:lowercaseAlbum])
        {
            thisAlbum = album;
            break;
        }
    }
    if (!thisAlbum)
    {
        thisAlbum = [NSMutableArray array];
        [thisAlbum addObject:file];
        [albumsForArtist addObject:thisAlbum];
        NSString * artworkKey = [NSString stringWithFormat:@"%@|~|%@", lowercaseArtist, lowercaseAlbum];
        [_lowercaseAlbums addObject:artworkKey];
        [albumsForArtist sortUsingSelector:@selector(albumSort:)];
        if ((![_albumsWithArtwork containsObject:artworkKey]) && ([self artworkExistsForArtist:lowercaseArtist album:lowercaseAlbum]))
            [_albumsWithArtwork addObject:artworkKey];
    }
    else
    {
        [thisAlbum addObject:file];
        [thisAlbum sortUsingSelector:@selector(compareByNumber:)];
    }
}

- (void)removeFile:(NetworkAudioFile *)file {
    // TODO: Remove from all lists
    // Re-sort
}


- (NetworkAudioFile *)mergeAudioFile:(NetworkAudioFile *)networkAudioFile withExistingObjects:(NSDictionary *)allExistingObjects withNewObjectArray:(NSMutableArray *)newObjects {
    
    
    // First try to get managed instance of this
    NetworkAudioFile * existingFile = [allExistingObjects valueForKey:networkAudioFile.primaryKey];
    if (!existingFile)
    {
        [newObjects addObject:networkAudioFile];
        if ((!networkAudioFile.artist) || (networkAudioFile.artist.length < 1))
            networkAudioFile.artist = @"Unknown Artist";
        if ((!networkAudioFile.album) || (networkAudioFile.album.length < 1))
            networkAudioFile.album = @"Unknown Album";
        if (!networkAudioFile.trackNumber)
            networkAudioFile.trackNumber = [NSNumber numberWithInteger:0];
        return networkAudioFile;
    }
    else
    {
        //NSLog(@"Existing edit for %@ exists", networkAudioFile.primaryKey);
        NSString * originalArtist = [existingFile.artist lowercaseString];
        NSString * originalAlbum = [existingFile.album lowercaseString];
        if (networkAudioFile.trackNumber)
            existingFile.trackNumber = networkAudioFile.trackNumber;
        if (networkAudioFile.artist)
            existingFile.artist = networkAudioFile.artist;
        if (networkAudioFile.album)
            existingFile.album = networkAudioFile.album;
        if (networkAudioFile.title)
            existingFile.title = networkAudioFile.title;
        if (networkAudioFile.duration)
            existingFile.duration = networkAudioFile.duration;
        if ((originalArtist) || (originalAlbum))
        {
            if (![originalArtist isEqualToString:[networkAudioFile.artist lowercaseString]])
            {
                existingFile.artistArtworkFile = nil;
                existingFile.albumArtworkFile = nil;
            }
            else if (![originalAlbum isEqualToString:[networkAudioFile.album lowercaseString]])
                existingFile.albumArtworkFile = nil;
        }
        if ((!existingFile.artist) || (existingFile.artist.length < 1))
            existingFile.artist = @"Unknown Artist";
        if ((!existingFile.album) || (existingFile.album.length < 1))
            existingFile.album = @"Unknown Album";
        return existingFile;
    }
}

- (void)mergeChangesForAudioFiles:(NSArray *)audioFiles
{
    @synchronized (_syncLocker)
    {
        NSLog(@"AudioFactory.mergeChangesForDevice starting");
        NSDate * startDate = [NSDate date];
        NSDictionary * allExistingObjects;
        @synchronized (_allObjects)
        {
            allExistingObjects = [_allObjectsById copy];
        }
        NSMutableArray * newObjects = [NSMutableArray array];
        for (NetworkAudioFile * networkAudioFile in audioFiles)
        {
            // If this file exists in our existing set then perform a merge of the data, otherwise
            // create a new file
            NetworkAudioFile * mergeFile = [self mergeAudioFile:networkAudioFile withExistingObjects:allExistingObjects withNewObjectArray:newObjects];
            mergeFile.lastSeen = startDate;
            mergeFile.isOnline = [NSNumber numberWithBool:YES];
        }
        
        // If we got any new files then merge them in to the master repository list
        if ([newObjects count] > 0)
            @synchronized (_allObjects)
        {
            for (NetworkAudioFile * file in newObjects)
                [self addNewFile:file];
        }
        
        NSLog(@"AudioFactory.mergeChangesForDevice completed successfully with %lu new files and %lu total", (unsigned long)[newObjects count], (unsigned long)[audioFiles count]);
    }
}

- (void)mergeNotificationChangesForDevice:(NSString *)deviceIdentifier added:(NSArray *)addedFiles deleted:(NSArray *)deletedFiles online:(NSArray *)onlineFiles offline:(NSArray *)offlineFiles updated:(NSArray *)updatedFiles {
    @synchronized (_syncLocker)
    {
        NSDictionary * allExistingObjects;
        @synchronized (_allObjects)
        {
            allExistingObjects = [_allObjectsById copy];
        }
        NSMutableArray * newObjects = [NSMutableArray array];
        NSDate * startDate = [NSDate date];
        
        // For any online files update their last seen
        NSArray * arrays = [NSArray arrayWithObjects:onlineFiles, newObjects, updatedFiles, nil];
        for (NSArray * array in arrays)
            for (NetworkAudioFile * audioFile in array)
            {
                NetworkAudioFile * mergeFile = [self mergeAudioFile:audioFile withExistingObjects:allExistingObjects withNewObjectArray:newObjects];
                mergeFile.lastSeen = startDate;
                mergeFile.isOnline = [NSNumber numberWithBool:YES];
                mergeFile.device = deviceIdentifier;
            }
        for (NetworkAudioFile * offlineFile in offlineFiles)
        {
            offlineFile.lastSeen = startDate;
            offlineFile.isOnline = [NSNumber numberWithBool:NO];
        }
        
        // Synchronize changes back
        if (([newObjects count] > 0) || (deletedFiles.count > 0))
            @synchronized (_allObjects)
        {
            if (newObjects.count > 0)
                for (NetworkAudioFile * file in newObjects)
                    [self addNewFile:file];
            if (deletedFiles.count > 0)
                for (NetworkAudioFile * file in deletedFiles)
                    [self removeFile:file];
        }
        NSLog(@"AudioFactory.mergeChangesForDevice completed successfully");
    }
}


#pragma mark -
#pragma mark Reading
- (NSArray *)availableAlbumsForArtist:(NSString *)artist {
    NSDictionary * albumCopy;
    @synchronized (_allObjects)
    {
        albumCopy = [_albumsForArtist copy];
    }
    if (![albumCopy containsKey:[artist lowercaseString]])
        return nil;
    return [[albumCopy objectForKey:[artist lowercaseString]] copy];
}

- (NSArray *)availableArtists {
    @synchronized (_allObjects)
    {
        return [_artists copy];
    }
}

- (NetworkAudioFile *)readForId:(NSNumber *)audioFileId forDevice:(NSString *)device {
    NSString * key = [NSString stringWithFormat:@"%@~%@", audioFileId, device];
    @synchronized (_allObjects)
    {
        return [_allObjectsById containsKey:key] ? [_allObjectsById valueForKey:key] : nil;
    }
}


#pragma mark -
#pragma mark Device Control
- (void)setDeviceOffline:(NSString *)deviceIdentifier
{
    NSArray * allExistingObjects;
    @synchronized (_allObjects)
    {
        allExistingObjects = [_allObjects copy];
    }
    int offlineCount = 0;
    for (NetworkAudioFile * file in allExistingObjects)
        if (([file.device isEqualToString:deviceIdentifier]) && ([file.isOnline boolValue]))
        {
            file.isOnline = [NSNumber numberWithBool:NO];
            offlineCount++;
        }
    if (offlineCount == 0)
        NSLog(@"No files found to mark offline for device %@", deviceIdentifier);
    else
        NSLog(@"Marked %d files offline for device %@", offlineCount, deviceIdentifier);
}

- (void)setAllOfflineAndRemoveOld {
    NSArray * allExistingObjects;
    @synchronized (_allObjects)
    {
        allExistingObjects = [_allObjects copy];
    }
    int offlineCount = 0;
    NSMutableArray * toDelete = [NSMutableArray array];
    double maxSeen = 3600 * 24 * 28;
    for (NetworkAudioFile * file in allExistingObjects)
    {
        double lastSeen = [file.lastSeen timeIntervalSinceNow] * -1;
        if (lastSeen > maxSeen)
        {
            [toDelete addObject:file];
        }
        else if ([file.isOnline boolValue])
        {
            file.isOnline = [NSNumber numberWithBool:NO];
            offlineCount++;
        }
    }
    if (offlineCount == 0)
        NSLog(@"No files found to mark offline");
    else
        NSLog(@"Marked %d files offline", offlineCount);
    if (toDelete.count > 0)
    {
        @synchronized (_allObjects)
        {
            for (NetworkAudioFile * file in toDelete)
                [self removeFile:file];
        }
        NSLog(@"Deleted %lu old files", (unsigned long)toDelete.count);
    }
    else
        NSLog(@"No old files found to delete");
}

#pragma mark -
#pragma mark Artwork
- (BOOL)artworkExistsForArtist:(NSString *)artist {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self artworkPathForArtist:artist]];
}

- (BOOL)artworkExistsForArtist:(NSString *)artist album:(NSString *)album {
    return [[NSFileManager defaultManager] fileExistsAtPath:[self artworkPathForArtist:artist album:album]];
}

- (NSString *)artworkPathForArtist:(NSString *)artist {
    return [_artistArtworkBasePath stringByAppendingPathComponent:[self artworkFilenameForArtist:artist]];
}

- (NSString *)artworkPathForArtist:(NSString *)artist album:(NSString *)album {
    return [_albumArtworkBasePath stringByAppendingPathComponent:[self artworkFilenameForArtist:artist album:album]];
}

- (NSString *)artworkFilenameForArtist:(NSString *)artist {
    return [NSString stringWithFormat:@"%@.png", [[artist lowercaseString] stringByReplacingOccurrencesOfString:@"/" withString:@"_"]];
}

- (NSString *)artworkFilenameForArtist:(NSString *)artist album:(NSString *)album {
    return [NSString stringWithFormat:@"%@|~|%@.png", [[artist lowercaseString] stringByReplacingOccurrencesOfString:@"/" withString:@"_"], [[album lowercaseString] stringByReplacingOccurrencesOfString:@"/" withString:@"_"]];
}

- (NSArray *)artistsWithoutArtwork {
    NSArray * allArtists = [self availableArtists];
    NSMutableArray * result = [NSMutableArray array];
    NSArray * artistsWithArtwork;
    @synchronized (_allObjects)
    {
        artistsWithArtwork = [_artistsWithArtwork copy];
    }
    for (NSString * artist in allArtists)
        if ((![artistsWithArtwork containsObject:[artist lowercaseString]]) && (![[artist lowercaseString] isEqualToString:@"unknown artist"]))
            [result addObject:artist];
    return result;
}

// Returns NS Dictionary keyed by artist name and within each key containing an NSArray of all the albums that artist has without artwork available
- (NSDictionary *)albumsWithoutArtwork {
    NSMutableDictionary * result = [NSMutableDictionary dictionary];
    NSArray * albumsWithArtwork;
    NSArray * lowercaseAlbums;
    @synchronized (_allObjects)
    {
        lowercaseAlbums = [_lowercaseAlbums copy];
        albumsWithArtwork = [_albumsWithArtwork copy];
    }
    for (NSString * album in lowercaseAlbums)
        if (![albumsWithArtwork containsObject:album])
        {
            // Parse out the artist - album pair from this
            NSArray * parts = [album componentsSeparatedByString:@"|~|"];
            if (parts.count < 2)
                continue;
            NSString * artist = [parts objectAtIndex:0];
            NSString * album = [parts objectAtIndex:1];
            
            // Skip if either pair is Unknown Artist / Unknown Album
            if (([artist isEqualToString:@"unknown artist"]) || ([album isEqualToString:@"unknown album"]))
                continue;
            
            // Add to results
            if (![result containsKey:artist])
                [result setObject:[NSMutableArray array] forKey:artist];
            NSMutableArray * albums = [result objectForKey:artist];
            if (![albums containsObject:album])
                [albums addObject:album];
        }
    
    return result;
}

- (void)setArtworkForArtist:(NSString *)artist data:(NSData *)data {
    NSError * error;
    [data writeToFile:[self artworkPathForArtist:artist] options:0 error:&error];
    if (error) {
        NSLog(@"Error writing file for %@ to disk.  %@", artist, error);
        return;
    }
    NSString * lowercaseArtist = [artist lowercaseString];
    if (![_artistsWithArtwork containsObject:lowercaseArtist])
        [_artistsWithArtwork addObject:lowercaseArtist];
}

- (void)setArtworkForArtist:(NSString *)artist album:(NSString *)album data:(NSData *)data {
    NSError * error;
    [data writeToFile:[self artworkPathForArtist:artist album:album] options:0 error:&error];
    if (error) {
        NSLog(@"Error writing file for %@ - %@ to disk.  %@", artist, album, error);
        return;
    }
    NSString * key = [NSString stringWithFormat:@"%@|~|%@", [artist lowercaseString], [album lowercaseString]];
    if (![_albumsWithArtwork containsObject:key])
        [_albumsWithArtwork addObject:key];
}

- (UIImage *)imageForArtist:(NSString *)artist {
    // First - try the artist image
    if ([self artworkExistsForArtist:artist])
        return [UIImage imageWithData:[NSData dataWithContentsOfFile:[self artworkPathForArtist:artist]]];
    
    // Next let's see if we have any album images for this artist, if so we'll use that
    NSArray * albumsWithArtwork;
    @synchronized (_allObjects)
    {
        albumsWithArtwork = [_albumsWithArtwork copy];
    }
    NSString * keyPrefix = [NSString stringWithFormat:@"%@|~|", [artist lowercaseString]];
    for (NSString * key in albumsWithArtwork)
    {
        if (![key hasPrefix:keyPrefix])
            continue;
        NSArray * parts = [key componentsSeparatedByString:@"|~|"];
        if (parts.count < 2)
            continue;
        NSString * album = [parts objectAtIndex:1];
        if ([self artworkExistsForArtist:artist album:album])
            return [UIImage imageWithData:[NSData dataWithContentsOfFile:[self artworkPathForArtist:artist album:album]]];
    }
    
    // Finally we have no possibilities left
    return nil;
}

- (UIImage *)imageForArtist:(NSString *)artist album:(NSString *)album {
    // First - try the album image itself
    if ([self artworkExistsForArtist:artist album:album])
        return [UIImage imageWithData:[NSData dataWithContentsOfFile:[self artworkPathForArtist:artist album:album]]];
    
    // Now see if we have an artist image
    if ([self artworkExistsForArtist:artist])
        return [UIImage imageWithData:[NSData dataWithContentsOfFile:[self artworkPathForArtist:artist]]];
    
    // Finally we have no possibilities left
    return nil;
}

@end