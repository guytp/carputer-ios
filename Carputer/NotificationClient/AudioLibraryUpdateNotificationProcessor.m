#import "AudioLibraryUpdateNotificationProcessor.h"
#import "NetworkAudioLibraryUpdateNotification.h"
#import "AudioFileFactory.h"
#import "NetworkAudioFile.h"

@implementation AudioLibraryUpdateNotificationProcessor
- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Setup defaults
    _notificationCode = 0x01;
    _opCode = 0x01;
    
    // Return self
    return self;
}

- (id)notificationObjectForJson:(id)jsonObject deviceSerialNumber:(NSString *)deviceSerialNumber {
    // Return if not right data source
    if (![[jsonObject class] isSubclassOfClass:[NSDictionary class]])
    {
        NSLog(@"Invalid JSON object passed to AudioLibraryUpdateNotificationProcessor");
        return nil;
    }
    NSDictionary * jsonDictionary = jsonObject;
    
    // Get AudioFiles for those with IDs
    NSMutableArray* deletedFiles = [NSMutableArray array];
    NSMutableArray* onlineFiles = [NSMutableArray array];
    NSMutableArray* offlineFiles = [NSMutableArray array];
    NSMutableArray* addedFiles = [NSMutableArray array];
    NSMutableArray* updatedFiles = [NSMutableArray array];
    NSArray * deletedFileIds = [jsonDictionary objectForKey:@"DeletedFiles"];
    if ([deletedFileIds isKindOfClass:[NSNull class]])
        deletedFileIds = nil;
    if (deletedFileIds)
    {
        for (NSNumber * fileId in deletedFileIds)
        {
            AudioFile * audioFile = [[AudioFileFactory applicationInstance] readForId:fileId forDevice:deviceSerialNumber];
            if (audioFile)
            [deletedFiles addObject:audioFile];
        }
    }
    NSArray * offlineFileIds = [jsonDictionary objectForKey:@"OfflineFiles"];
    if ([offlineFileIds isKindOfClass:[NSNull class]])
        offlineFileIds = nil;
    if (offlineFileIds)
    {
        for (NSNumber * fileId in offlineFileIds)
        {
            AudioFile * audioFile = [[AudioFileFactory applicationInstance] readForId:fileId forDevice:deviceSerialNumber];
            if (audioFile)
                [offlineFiles addObject:audioFile];
        }
    }
    NSArray * addedJsonObjects = [jsonDictionary objectForKey:@"NewFiles"];
    if ([addedJsonObjects isKindOfClass:[NSNull class]])
        addedJsonObjects = nil;
    if (addedJsonObjects)
    {
        for (NSDictionary * jsonObject in addedJsonObjects)
            [addedFiles addObject:[[NetworkAudioFile alloc] initWithJsonObject:jsonObject]];
    }
    NSArray * onlineJsonObjects = [jsonDictionary objectForKey:@"OnlineFiles"];
    if ([onlineJsonObjects isKindOfClass:[NSNull class]])
        onlineJsonObjects = nil;
    if (onlineJsonObjects)
    {
        for (NSDictionary * jsonObject in onlineJsonObjects)
            [onlineFiles addObject:[[NetworkAudioFile alloc] initWithJsonObject:jsonObject]];
    }
    NSArray * updatedJsonObjects = [jsonDictionary objectForKey:@"UpdatedFiles"];
    if ([updatedJsonObjects isKindOfClass:[NSNull class]])
        updatedJsonObjects = nil;
    if (updatedJsonObjects)
    {
        for (NSDictionary * jsonObject in updatedJsonObjects)
            [updatedFiles addObject:[[NetworkAudioFile alloc] initWithJsonObject:jsonObject]];
    }
    
    // Extract all other data
    NetworkAudioLibraryUpdateNotification * n = [[NetworkAudioLibraryUpdateNotification alloc] init];
    n.deviceIdentifier = deviceSerialNumber;
    n.addedFiles = addedFiles;
    if ([n.addedFiles isKindOfClass:[NSNull class]])
        n.addedFiles = nil;
    n.onlineFiles = onlineFiles;
    n.offlineFiles = offlineFiles;
    n.deletedFiles = deletedFiles;
    n.updatedFiles = updatedFiles;
    if ([n.updatedFiles isKindOfClass:[NSNull class]])
        n.updatedFiles = nil;
    
    // Merge these changes in the database
    [[AudioFileFactory applicationInstance] mergeNotificationChangesForDevice:deviceSerialNumber added:n.addedFiles deleted:n.deletedFiles online:n.onlineFiles offline:n.offlineFiles updated:n.updatedFiles];
    
    // Return the notification to clients
    return n;
}
@end