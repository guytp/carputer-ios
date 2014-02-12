#import <Foundation/Foundation.h>

@interface ArtworkGetResponse : NSObject

@property NSData * artistImageData;
@property NSData * albumImageData;
@property NSNumber * artistImageAvailable;
@property NSNumber * albumImageAvailable;

@property NSString * requestedArtist;
@property NSString * requestedAlbum;
@property BOOL requestedGetArtistImage;
@property BOOL requestedGetAlbumImage;
@end