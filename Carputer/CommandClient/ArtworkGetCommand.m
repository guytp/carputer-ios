#import "ArtworkGetCommand.h"
#import "NSDictionary+Dictionary_ContainsKey.h"
#import "CommandClient.h"
#import "ArtworkGetResponse.h"

@implementation ArtworkGetCommand

- (id)init {
    // Call to base
    self = [super init];
    if (!self)
        return nil;
    
    // Store values
    _category = 0x01;
    _opcode = 0x09;
    _responseExpected = YES;
    _responseJsonType = [NSDictionary class];
    
    // Return self
    return self;
}

- (id)initWithArtist:(NSString *)artist {
    // Call to self
    self = [self init];
    if (!self)
        return nil;
    
    // Setup class
    _artist = artist;
    _album = nil;
    _getArtistImage = YES;
    _getAlbumImage = NO;
    
    // Return self
    return self;
}

- (id)initWithArtist:(NSString *)artist album:(NSString *)album getArtistImage:(BOOL)getArtistImage {
    // Call to self
    self = [self init];
    if (!self)
        return nil;
    
    // Setup class
    _artist = artist;
    _album = album;
    _getArtistImage = getArtistImage;
    _getAlbumImage = YES;
    
    // Return self
    return self;
}



- (NSData *) jsonRepresentationWithError:(NSError **)error {
    NSMutableDictionary * jsonObject = [[NSMutableDictionary alloc] init];
    if (_artist)
        [jsonObject setObject:_artist forKey:@"Artist"];
    if (_album)
        [jsonObject setObject:_album forKey:@"Album"];
    [jsonObject setObject:[NSNumber numberWithBool:_getArtistImage] forKey:@"GetArtistImage"];
    [jsonObject setObject:[NSNumber numberWithBool:_getAlbumImage] forKey:@"GetAlbumImage"];
    return [NSJSONSerialization dataWithJSONObject:jsonObject options:kNilOptions error:error];
}

- (id) parseResponse:(id)jsonObject withError:(NSError **)parsingError {
    // Error check the contents of this message
    NSDictionary * jsonDictionary = (NSDictionary *)jsonObject;
    if ((![jsonDictionary containsKey:@"ArtistImageAvailable"]) || (![jsonDictionary containsKey:@"ArtistImageBase64"]) || (![jsonDictionary containsKey:@"AlbumImageAvailable"]) || (![jsonDictionary containsKey:@"AlbumImageBase64"]))
    {
        NSError * error = [[NSError alloc] initWithDomain:kCommandClientErrorDomain code:CommandClientErrorResponseParseFail userInfo:nil];
        *parsingError = error;
        return nil;
    }
    
    // Parse out in to a response object
    NSString * base64ArtistImage = [jsonDictionary objectForKey:@"ArtistImageBase64"];
    if (([base64ArtistImage isKindOfClass:[NSNull class]]) || (base64ArtistImage.length < 1))
        base64ArtistImage = nil;
    NSData * artistImageData = nil;
    if (base64ArtistImage)
        artistImageData = [[NSData alloc] initWithBase64EncodedString:base64ArtistImage options:0];
    NSString * base64AlbumImage = [jsonDictionary objectForKey:@"AlbumImageBase64"];
    if (([base64AlbumImage isKindOfClass:[NSNull class]]) || (base64AlbumImage.length < 1))
        base64AlbumImage = nil;
    NSData * albumImageData = nil;
    if (base64AlbumImage)
        albumImageData = [[NSData alloc] initWithBase64EncodedString:base64AlbumImage options:0];
    NSNumber * artistImageAvailable = [jsonDictionary objectForKey:@"ArtistImageAvailable"];
    if ([artistImageAvailable isKindOfClass:[NSNull class]])
        artistImageAvailable = nil;
    NSNumber * albumImageAvailable = [jsonDictionary objectForKey:@"AlbumImageAvailable"];
    if ([albumImageAvailable isKindOfClass:[NSNull class]])
        albumImageAvailable = nil;

    // Return the object as a response
    ArtworkGetResponse * response = [[ArtworkGetResponse alloc] init];
    response.artistImageData = artistImageData;
    response.albumImageData = albumImageData;
    response.artistImageAvailable = artistImageAvailable;
    response.albumImageAvailable = albumImageAvailable;
    response.requestedAlbum = _album;
    response.requestedArtist = _artist;
    response.requestedGetAlbumImage = _getAlbumImage;
    response.requestedGetArtistImage = _getArtistImage;
    return response;
}
@end