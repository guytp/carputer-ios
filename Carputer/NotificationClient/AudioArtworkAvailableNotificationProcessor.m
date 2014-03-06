#import "AudioArtworkAvailableNotificationProcessor.h"
#import "AudioFileFactory.h"
#import "NetworkAudioArtworkAvailableNotification.h"

@implementation AudioArtworkAvailableNotificationProcessor

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Setup defaults
    _notificationCode = 0x01;
    _opCode = 0x02;
    
    // Return self
    return self;
}

- (id)notificationObjectForJson:(id)jsonObject deviceSerialNumber:(NSString *)deviceSerialNumber {
    // Return if not right data source
    if (![[jsonObject class] isSubclassOfClass:[NSDictionary class]])
    {
        NSLog(@"Invalid JSON object passed to AudioArtworkAvailableNotificationProcessor");
        return nil;
    }
    NSDictionary * jsonDictionary = jsonObject;
    
    // Parse out data
    NSString * artist = [jsonDictionary objectForKey:@"Artist"];
    if (([artist isKindOfClass:[NSNull class]]) || ([artist length] < 1))
        artist = nil;
    NSString * album = [jsonDictionary objectForKey:@"Album"];
    if (([album isKindOfClass:[NSNull class]]) || ([album length] < 1))
        album = nil;
    NSString * imageContentBase64 = [jsonDictionary objectForKey:@"ImageContent"];
    if (([imageContentBase64 isKindOfClass:[NSNull class]]) || ([imageContentBase64 length] < 1))
        imageContentBase64 = nil;
    
    // Return a null object if we cannot parse artist out
    if (!artist)
        return nil;

    // Get NSData from Base 64 unless empty
    NSData * imageData;
    if (imageContentBase64)
        imageData = [[NSData alloc] initWithBase64EncodedString:imageContentBase64 options:0];
    
    // Store file on disk unless empty
    if (imageData)
    {
        // Merge these changes in the database
        if (!album)
            [[AudioFileFactory applicationInstance] setArtworkForArtist:artist data:imageData];
        else
            [[AudioFileFactory applicationInstance] setArtworkForArtist:artist album:album data:imageData];
    }
    else
        return nil;
    
    // Return the notification to clients
    NetworkAudioArtworkAvailableNotification * n = [[NetworkAudioArtworkAvailableNotification alloc] init];
    n.artist = artist;
    n.album = album;
    n.image = [UIImage imageWithData:imageData];
    return n;
}
@end