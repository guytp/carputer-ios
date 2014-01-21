#import "AudioLibraryGetCommand.h"
#import "NSDictionary+Dictionary_ContainsKey.h"
#import "CommandClient.h"
#import "NetworkAudioFile.h"

@implementation AudioLibrarGetCommand

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Store values
    _category = 0x01;
    _opcode = 0x00;
    _responseExpected = YES;
    _responseJsonType = [NSArray class];
    
    // Return self
    return self;
}

- (id)parseResponse:(id)jsonObject withError:(NSError **)parsingError {
    // Itterate through the array creating AudioFile objects
    NSArray * jsonArray = (NSArray *)jsonObject;
    NSMutableArray * audioFiles = [NSMutableArray array];
    for(NSDictionary * audioFileDictionary in jsonArray)
    {
        // Error check the contents of this message
        if ((![[audioFileDictionary class] isSubclassOfClass:[NSDictionary class]]) || (![audioFileDictionary containsKey:@"AudioFileId"]) || (![audioFileDictionary containsKey:@"Artist"]) || (![audioFileDictionary containsKey:@"Title"]) || (![audioFileDictionary containsKey:@"TrackNumber"]) || (![audioFileDictionary containsKey:@"Album"]) || (![audioFileDictionary containsKey:@"DurationSeconds"]))
        {
            NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorResponseParseFail userInfo:nil];
            *parsingError = error;
            return nil;
        }
        
        // Parse out to an AudioFie object
        NetworkAudioFile * audioFile = [[NetworkAudioFile alloc] init];
        audioFile.audioFileId = [audioFileDictionary objectForKey:@"AudioFileId"];
        audioFile.artist = [audioFileDictionary objectForKey:@"Artist"];
        if ([audioFile.artist isKindOfClass:[NSNull class]])
            audioFile.artist = nil;
        audioFile.album = [audioFileDictionary objectForKey:@"Album"];
        if ([audioFile.album isKindOfClass:[NSNull class]])
            audioFile.album = nil;
        audioFile.title = [audioFileDictionary objectForKey:@"Title"];
        if ([audioFile.title isKindOfClass:[NSNull class]])
            audioFile.title = nil;
        audioFile.trackNumber = [audioFileDictionary objectForKey:@"TrackNumber"];
        if ([audioFile.trackNumber isKindOfClass:[NSNull class]])
            audioFile.trackNumber = nil;
        audioFile.duration = [audioFileDictionary objectForKey:@"DurationSeconds"];
        if ([audioFile.duration isKindOfClass:[NSNull class]])
            audioFile.duration = nil;
        [audioFiles addObject:audioFile];
    }
    return audioFiles;
}
@end