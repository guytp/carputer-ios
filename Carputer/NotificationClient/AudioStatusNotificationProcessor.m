#import "AudioStatusNotificationProcessor.h"
#import "NetworkAudioStatusNotification.h"
#import "AudioFileFactory.h"

@implementation AudioStatusNotificationProcessor

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Setup defaults
    _notificationCode = 0x01;
    _opCode = 0x00;
    
    // Return self
    return self;
}

- (id)notificationObjectForJson:(id)jsonObject deviceSerialNumber:(NSString *)deviceSerialNumber {
    // Return if not right data source
    if (![[jsonObject class] isSubclassOfClass:[NSDictionary class]])
    {
        NSLog(@"Invalid JSON object passed to AudioStatusNotificationProcessor");
        return nil;
    }
    NSDictionary * jsonDictionary = jsonObject;
    
    // Extract all data and return the notification object
    NetworkAudioStatusNotification * n = [[NetworkAudioStatusNotification alloc] init];
    n.deviceIdentifier = deviceSerialNumber;
    n.playlistPosition = [((NSNumber *)[jsonDictionary objectForKey:@"PlaylistPosition"]) intValue];
    n.isPaused = [((NSNumber *)[jsonDictionary objectForKey:@"IsPaused"]) boolValue];
    n.isPlaying = [((NSNumber *)[jsonDictionary objectForKey:@"IsPlaying"]) boolValue];
    n.isShuffle = [((NSNumber *)[jsonDictionary objectForKey:@"IsShuffle"]) boolValue];
    n.isRepeatAll = [((NSNumber *)[jsonDictionary objectForKey:@"IsRepeatAll"]) boolValue];
    n.canMoveNext = [((NSNumber *)[jsonDictionary objectForKey:@"CanMoveNext"]) boolValue];
    n.canMovePrevious = [((NSNumber *)[jsonDictionary objectForKey:@"CanMovePrevious"]) boolValue];
    n.position = [((NSNumber *)[jsonDictionary objectForKey:@"Position"]) intValue];
    n.duration = [((NSNumber *)[jsonDictionary objectForKey:@"Duration"]) intValue];
    NSArray * tracks = [jsonDictionary objectForKey:@"Playlist"];
    NSMutableArray * playlist = [NSMutableArray array];
    for (NSNumber * track in tracks)
    {
        AudioFile * audioFile = [[AudioFileFactory applicationInstance] readForId:track forDevice:deviceSerialNumber];
        if (audioFile)
            [playlist addObject:audioFile];
    }
    n.playlist = playlist;
    return n;
}
@end