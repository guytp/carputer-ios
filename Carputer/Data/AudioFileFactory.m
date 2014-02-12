#import "AudioFileFactory.h"
#import "NetworkAudioFile.h"

@interface AudioFileFactory()
- (void)setAllOfflineAndRemoveOld;
- (AudioFile *)unlockedReadForId:(NSNumber *)audioFileId forDevice:(NSString *)deviceIdentifier;
@end

@implementation AudioFileFactory
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
    
    // Setup the factory
    NSArray * paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * documentsDirectory = [paths lastObject];
    NSString * persistentStorePath = [documentsDirectory stringByAppendingPathComponent:@"Carputer.sqlite"];
    NSURL * storeUrl = [NSURL fileURLWithPath:persistentStorePath];
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:nil]];
    NSError * error = nil;
    NSPersistentStore * persistentStore = [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:nil error:&error];
    NSAssert3(persistentStore != nil, @"Unhandled error adding persistent store in %s at line %d: %@", __FUNCTION__, __LINE__, [error localizedDescription]);
    _context = [[NSManagedObjectContext alloc] init];
    [_context setPersistentStoreCoordinator:_persistentStoreCoordinator];
    
    // Return self
    return self;
}

- (AudioFile *)audioFileFromNetworkAudioFile:(NetworkAudioFile *)networkAudioFile onDevice:(NSString *)deviceIdentifier {
    
    // First try to get managed instance of this
    AudioFile * audioFile = [self unlockedReadForId:networkAudioFile.audioFileId forDevice:deviceIdentifier];
    NSString * originalArtist = nil;
    NSString * originalAlbum = nil;
    if (!audioFile)
    {
        audioFile = [NSEntityDescription insertNewObjectForEntityForName:@"AudioFile" inManagedObjectContext:_context];
        audioFile.id = networkAudioFile.audioFileId;
        audioFile.device = deviceIdentifier;
    }
    else
    {
        originalArtist = [audioFile.artist lowercaseString];
        originalAlbum = [audioFile.album lowercaseString];
    }
    if (networkAudioFile.trackNumber)
        audioFile.trackNumber = networkAudioFile.trackNumber;
    if (networkAudioFile.artist)
        audioFile.artist = networkAudioFile.artist;
    if (networkAudioFile.album)
        audioFile.album = networkAudioFile.album;
    if (networkAudioFile.title)
        audioFile.title = networkAudioFile.title;
    if (networkAudioFile.duration)
        audioFile.duration = networkAudioFile.duration;
    if ((originalArtist) || (originalAlbum))
    {
        if (![originalArtist isEqualToString:[audioFile.artist lowercaseString]])
        {
            audioFile.artistArtworkFile = nil;
            audioFile.albumArtworkFile = nil;
        }
        else if (![originalAlbum isEqualToString:[audioFile.album lowercaseString]])
            audioFile.albumArtworkFile = nil;
    }
    return audioFile;
}

- (void)mergeChangesForDevice:(NSString *)deviceIdentifier withAudioFiles:(NSArray *)audioFiles
{
    NSLog(@"AudioFactory.mergeChangesForDevice starting");
    NSDate * startDate = [NSDate date];
    @synchronized (_context)
    {
        for (NetworkAudioFile * networkAudioFile in audioFiles)
        {
            // Update common settings
            AudioFile * audioFile = [self audioFileFromNetworkAudioFile:networkAudioFile onDevice:deviceIdentifier];
            audioFile.lastSeen = startDate;
            audioFile.isOnline = [NSNumber numberWithBool:YES];
        }
        
        // Save to context
        NSError * error = nil;
        [_context save:&error];
        if (error)
            NSLog(@"AudioFactory.mergeChangesForDevice failed to insert/update %@", deviceIdentifier);
        else
            NSLog(@"AudioFactory.mergeChangesForDevice completed successfully");
    }
}

- (void)mergeNotificationChangesForDevice:(NSString *)deviceIdentifier added:(NSArray *)addedFiles deleted:(NSArray *)deletedFiles online:(NSArray *)onlineFiles offline:(NSArray *)offlineFiles updated:(NSArray *)updatedFiles {
    NSLog(@"mergeNotificationChangesForDevice starting");
    NSDate * startDate = [NSDate date];
    @synchronized (_context)
    {
        // For any online files update their last seen
        for (NetworkAudioFile * networkAudioFile in onlineFiles)
        {
            AudioFile * audioFile = [self audioFileFromNetworkAudioFile:networkAudioFile onDevice:deviceIdentifier];
            audioFile.lastSeen = startDate;
            audioFile.isOnline = [NSNumber numberWithBool:YES];
        }
        
        // For any offline files update their status to now be offline
        for (AudioFile * offlineFile in offlineFiles)
            offlineFile.isOnline = [NSNumber numberWithBool:NO];
        
        // For any deleted files remove from context
        for (AudioFile * deletedFile in deletedFiles)
            [_context deleteObject:deletedFile];
        
        // For new files convert from a NetworkAudioFile in to an AudioFile and add to the system
        for (NetworkAudioFile * networkAudioFile in addedFiles)
        {
            AudioFile * audioFile = [self audioFileFromNetworkAudioFile:networkAudioFile onDevice:deviceIdentifier];
            audioFile.lastSeen = startDate;
            audioFile.isOnline = [NSNumber numberWithBool:YES];
        }
        
        // For any updated files update their corresponding counterpart and if it does not exist
        // then create it
        for (NetworkAudioFile * networkAudioFile in updatedFiles) {
            AudioFile * audioFile = [self audioFileFromNetworkAudioFile:networkAudioFile onDevice:deviceIdentifier];
            audioFile.lastSeen = startDate;
            audioFile.isOnline = [NSNumber numberWithBool:YES];
        }
        
        // Save to context
        NSError * error = nil;
        [_context save:&error];
        if (error)
            NSLog(@"AudioFactory.mergeChangesForDevice failed to insert/update %@", deviceIdentifier);
        else
            NSLog(@"AudioFactory.mergeChangesForDevice completed successfully");
    }
}

- (NSArray *)readAllActive
{
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"isOnline == YES"], nil]];
    NSSortDescriptor * artistSort = [[NSSortDescriptor alloc] initWithKey:@"artist" ascending:YES];
    NSSortDescriptor * albumSort = [[NSSortDescriptor alloc] initWithKey:@"album" ascending:YES];
    NSSortDescriptor * trackNumberSort = [[NSSortDescriptor alloc] initWithKey:@"trackNumber" ascending:YES];
    NSSortDescriptor * titleSort = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];
    fetchRequest.sortDescriptors = [[NSArray alloc] initWithObjects:artistSort, albumSort, trackNumberSort, titleSort, nil];
    
    
    @synchronized (_context)
    {
        NSError * error = nil;
        NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"Failed AudioFileFactory.readAllactive from CoreData: %@", error);
            return nil;
        }
        return results;
    }
}

- (void)setDeviceOffline:(NSString *)deviceIdentifier
{
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"isOnline == YES"], [NSPredicate predicateWithFormat:@"device == %@", deviceIdentifier], nil]];
    @synchronized (_context)
    {
        NSError * error = nil;
        NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"Failed AudioFileFactory.setDeviceOffline from CoreData: %@", error);
            return;
        }
        if ((!results) || (results.count < 1))
        {
            NSLog(@"No files found to mark offline for device %@", deviceIdentifier);
            return;
        }
        for (AudioFile * file in results)
        {
            file.isOnline = [NSNumber numberWithBool:NO];
            NSLog(@"Setting offline for %@", file.id);
        }
        [_context save:&error];
        if (error)
        {
            NSLog(@"Failed AudioFileFactory.setDeviceOffline from CoreData: %@", error);
            return;
        }
    }
}

- (NSArray *)readAllActiveForArtist:(NSString *)artist {
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"isOnline == YES"], [NSPredicate predicateWithFormat:@"artist ==[c] %@", artist], nil]];
    NSSortDescriptor * artistSort = [[NSSortDescriptor alloc] initWithKey:@"artist" ascending:YES];
    NSSortDescriptor * albumSort = [[NSSortDescriptor alloc] initWithKey:@"album" ascending:YES];
    NSSortDescriptor * trackNumberSort = [[NSSortDescriptor alloc] initWithKey:@"trackNumber" ascending:YES];
    NSSortDescriptor * titleSort = [[NSSortDescriptor alloc] initWithKey:@"title" ascending:YES];
    fetchRequest.sortDescriptors = [[NSArray alloc] initWithObjects:artistSort, albumSort, trackNumberSort, titleSort, nil];
    
    
    @synchronized (_context)
    {
        NSError * error = nil;
        NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"Failed AudioFileFactory.readAllactiveForArtist from CoreData: %@", error);
            return nil;
        }
        return results;
    }
}

- (void)setAllOfflineAndRemoveOld {
    @synchronized (_context)
    {
        NSLog(@"AudioFileFactory.setAllOfflineAndRemoveOld starting");
        
        NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
        NSError * error = nil;
        NSArray * audioFiles = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"AudioFileFactory.setAllOfflineAndRemoveOld failed to read existing");
            return;
        }
        double maxSeen = 3600 * 24 * 28;
        for (AudioFile * audioFile in audioFiles)
        {
            audioFile.isOnline = [NSNumber numberWithBool:NO];
            
            double lastSeen = [audioFile.lastSeen timeIntervalSinceNow] * -1;
            if (lastSeen > maxSeen)
                [_context deleteObject:audioFile];
        }
        [_context save:&error];
        if (error)
            NSLog(@"AudioFileFactory.setAllOfflineAndRemoveOld error updating: %@", error);
        else
            NSLog(@"AudioFileFactory.setAllOfflineAndRemoveOld updated core data successfully");
    }
}

- (AudioFile *)readForId:(NSNumber *)audioFileId forDevice:(NSString *)deviceIdentifier
{
    @synchronized (_context)
    {
        return [self unlockedReadForId:audioFileId forDevice:deviceIdentifier];
    }
}

- (AudioFile *)unlockedReadForId:(NSNumber *)audioFileId forDevice:(NSString *)deviceIdentifier
{
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"id == %@", audioFileId], [NSPredicate predicateWithFormat:@"device == %@", deviceIdentifier]]];
    NSError * error = nil;
    NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
    if (error)
    {
        NSLog(@"Failed readForId from CoreData: %@", error);
        return nil;
    }
    return [results count] > 0 ? [results objectAtIndex:0] : nil;
}

- (NSArray *)readAllActiveForDevice:(NSString *)deviceIdentifier notSeenSince:(NSDate *)sinceDate
{
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"lastSeen < %@", sinceDate], [NSPredicate predicateWithFormat:@"device == %@", deviceIdentifier]]];
    NSError * error = nil;
    @synchronized (_context)
    {
        NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"Failed readAllActiveForDevice from CoreData: %@", error);
            return nil;
        }
        return results;
    }
}

- (NSArray *)audioFilesWithoutArtwork {
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [NSCompoundPredicate orPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"albumArtworkFile == NULL"], [NSPredicate predicateWithFormat:@"artistArtworkFile == NULL"]]];
    NSError * error = nil;
    @synchronized (_context)
    {
        NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"Failed audioFilesWithoutArtwork from CoreData: %@", error);
            return nil;
        }
        return results;
    }
}

- (void)setArtworkForArtist:(NSString *)artist withFile:(NSString *)file {
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [NSPredicate predicateWithFormat:@"artist ==[c] %@", artist];
    NSError * error = nil;
    
    NSLog(@"Setting %@ to be %@", artist, file);
    @synchronized (_context)
    {
        NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"Failed setArtworkForArtist (Get) from CoreData: %@", error);
            return;
        }
        if (!results)
            return;
        for (AudioFile * audioFile in results)
            audioFile.artistArtworkFile = file;
        [_context save:&error];
        if (error)
        {
            NSLog(@"Failed setArtworkForArtist (Update) from CoreData: %@", error);
            return;
        }
    }
}

- (void)setArtworkForArtist:(NSString *)artist album:(NSString *)album withFile:(NSString *)file {
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"album ==[c] %@", album],[NSPredicate predicateWithFormat:@"artist ==[c] %@", artist]]];
    NSError * error = nil;
    
    NSLog(@"Setting %@ - %@ to be %@", artist, album, file);
    @synchronized (_context)
    {
        NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"Failed setArtworkForArtistAlbum (Get) from CoreData: %@", error);
            return;
        }
        if (!results)
            return;
        for (AudioFile * audioFile in results)
            audioFile.albumArtworkFile = file;
        [_context save:&error];
        if (error)
        {
            NSLog(@"Failed setArtworkForArtistAlbum (Update) from CoreData: %@", error);
            return;
        }
    }
}

- (UIImage *)imageForArtist:(NSString *)artist {
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"artistArtworkFile != %@", @""], [NSPredicate predicateWithFormat:@"artistArtworkFile != NULL"],[NSPredicate predicateWithFormat:@"artist ==[c] %@", artist]]];
    NSError * error = nil;
    @synchronized (_context)
    {
        NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"Failed imageForArtist from CoreData: %@", error);
            return nil;
        }
        if ((!results) || (results.count < 1))
        {
            // Try to change the request to lookup an album artwork file
            fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"albumArtworkFile != %@", @""], [NSPredicate predicateWithFormat:@"albumArtworkFile != NULL"],[NSPredicate predicateWithFormat:@"artist ==[c] %@", artist]]];
            results = [_context executeFetchRequest:fetchRequest error:&error];
            if (error)
            {
                NSLog(@"Failed imageForArtist from CoreData: %@", error);
                return nil;
            }
            if ((!results) || (results.count < 1))
                return nil;
            
            AudioFile * audioFileAlbum = [results objectAtIndex:0];
            return [UIImage imageWithContentsOfFile:audioFileAlbum.albumArtworkFile];
        }
        AudioFile * audioFile = [results objectAtIndex:0];
        return [UIImage imageWithContentsOfFile:audioFile.artistArtworkFile];
    }
}

- (UIImage *)imageForArtist:(NSString *)artist album:(NSString *)album {
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"albumArtworkFile != %@", @""], [NSPredicate predicateWithFormat:@"albumArtworkFile != NULL"],[NSPredicate predicateWithFormat:@"artist == %@", artist],[NSPredicate predicateWithFormat:@"album ==[c] %@", album]]];
    NSError * error = nil;
    @synchronized (_context)
    {
        NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
        if (error)
        {
            NSLog(@"Failed imageForArtistAlbum from CoreData: %@", error);
            return nil;
        }
        if ((!results) || (results.count < 1))
        {
            // Try to change the request to lookup an artist artwork file
            fetchRequest.predicate = [NSCompoundPredicate andPredicateWithSubpredicates:@[[NSPredicate predicateWithFormat:@"artistArtworkFile != %@", @""], [NSPredicate predicateWithFormat:@"artistArtworkFile != NULL"],[NSPredicate predicateWithFormat:@"artist ==[c] %@", artist]]];
            results = [_context executeFetchRequest:fetchRequest error:&error];
            if (error)
            {
                NSLog(@"Failed imageForArtistAlbum from CoreData: %@", error);
                return nil;
            }
            if ((!results) || (results.count < 1))
                return nil;
            
            AudioFile * audioFileArtist = [results objectAtIndex:0];
            return [UIImage imageWithContentsOfFile:audioFileArtist.artistArtworkFile];
        }
        AudioFile * audioFile = [results objectAtIndex:0];
        return [UIImage imageWithContentsOfFile:audioFile.albumArtworkFile];
    }
}
@end