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
        _applicationInstance = [[AudioFileFactory alloc] init];
        
        // As we're starting up first step is to update the data source so that isOnline is false
        // and that anything not seen in 28 days is deleted
        [_applicationInstance setAllOfflineAndRemoveOld];
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

- (void)mergeChangesForDevice:(NSString *)deviceIdentifier withAudioFiles:(NSArray *)audioFiles
{
    NSLog(@"AudioFactory.mergeChangesForDevice starting");
    NSDate * startDate = [NSDate date];
    @synchronized (_context)
    {
        for (NetworkAudioFile * networkAudioFile in audioFiles)
        {
            // First try to get managed instance of this
            AudioFile * audioFile = [self unlockedReadForId:networkAudioFile.audioFileId forDevice:deviceIdentifier];
            if (audioFile)
            {
                //NSLog(@"AudioFileFactory.readAllactive.mergeChangesForDevice found existing for %@ on %@", networkAudioFile.audioFileId, deviceIdentifier);
            }
            else
            {
                //NSLog(@"AudioFileFactory.readAllactive.mergeChangesForDevice new file %@ on %@", networkAudioFile.audioFileId, deviceIdentifier);
                audioFile = [NSEntityDescription insertNewObjectForEntityForName:@"AudioFile" inManagedObjectContext:_context];
                audioFile.id = networkAudioFile.audioFileId;
                audioFile.device = deviceIdentifier;
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
            }
            
            // Update common settings
            audioFile.lastSeen = startDate;
            audioFile.isOnline = [NSNumber numberWithBool:YES];
            audioFile.seenInLastSync = [NSNumber numberWithBool:YES];
        }
        
        // Update those not seen in this sync
        NSArray * notSeenAudioFiles = [self readAllActiveForDevice:deviceIdentifier notSeenSince:startDate];
        for (AudioFile * notSeenAudioFile in notSeenAudioFiles)
        {
            notSeenAudioFile.isOnline = [NSNumber numberWithBool:YES];
            notSeenAudioFile.seenInLastSync = [NSNumber numberWithBool:NO];
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
    fetchRequest.predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"isOnline == YES"], [NSPredicate predicateWithFormat:@"seenInLastSync == YES"], nil]];
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

- (NSArray *)readAllActiveForArtist:(NSString *)artist {
    NSFetchRequest * fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"AudioFile"];
    fetchRequest.predicate = [[NSCompoundPredicate alloc] initWithType:NSAndPredicateType subpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"isOnline == YES"], [NSPredicate predicateWithFormat:@"seenInLastSync == YES"], [NSPredicate predicateWithFormat:@"artist ==[c] %@", artist], nil]];
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
    NSArray * results = [_context executeFetchRequest:fetchRequest error:&error];
    if (error)
    {
        NSLog(@"Failed readAllActiveForDevice from CoreData: %@", error);
        return nil;
    }
    return results;
}
@end