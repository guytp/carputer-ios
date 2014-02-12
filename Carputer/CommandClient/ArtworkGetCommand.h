#import "CommandBase.h"

@interface ArtworkGetCommand : CommandBase
{
@private
    NSString * _artist;
    NSString * _album;
    BOOL _getArtistImage;
    BOOL _getAlbumImage;
}


- (id)initWithArtist:(NSString *)artist;

- (id)initWithArtist:(NSString *)artist album:(NSString *)album getArtistImage:(BOOL)getArtistImage;

@end