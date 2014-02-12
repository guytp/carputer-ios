#import "ArtistCollectionViewCell.h"
#import "ClientController.h"
#import "NotificationClient.h"
#import "ArtworkGetResponse.h"
#import "NetworkAudioArtworkAvailableNotification.h"

@implementation ArtistCollectionViewCell

- (void)dealloc {
    if (_registeredNotifications)
        [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)label {
    return _label.text;
}

- (void)setupForArtist:(NSString *)artist withImage:(UIImage *)image {
    // Register for notifications if we haven't yet
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(artworkNotification:) name:kNotificationClientNotificationName object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(artworkNotification:) name:kClientControllerNewArtworkNotificationName object:nil];
    
    // Setup views from details supplied
    _label.text = artist;
    //_label.numberOfLines = 0;
    //CGSize size = [_label sizeThatFits:CGSizeMake(200, 70)];
    //_label.frame = CGRectMake(_label.frame.origin.x, _label.frame.origin.y, 200, size.height);
    _imageView.image = image;
    
    // If no image is supplied then fill with a random colour
    if (!image)
    {
        CGFloat hue = ( arc4random() % 256 / 256.0 );
        CGFloat saturation = ( arc4random() % 128 / 256.0 ) + 0.5;
        CGFloat brightness = ( arc4random() % 128 / 256.0 ) + 0.5;
        _imageView.backgroundColor = [UIColor colorWithHue:hue saturation:saturation brightness:brightness alpha:1];
    }
    else
        _imageView.backgroundColor = [UIColor clearColor];
}

- (void)artworkNotification:(id)notification {
    // If we have an image no need to load a new one
    if (_imageView.image)
        return;
    
    // Call back to UI if required
    if ([NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(artworkNotification:) withObject:notification waitUntilDone:NO];
        return;
    }
    
    // Determine if this is an appropriate notification for us
    if ([notification isKindOfClass:[ArtworkGetResponse class]])
    {
        ArtworkGetResponse * artworkGetResponse = notification;
        if (![[artworkGetResponse.requestedArtist lowercaseString] isEqualToString:[_label.text lowercaseString]])
            return;
        _imageView.image = artworkGetResponse.artistImageAvailable ? [UIImage imageWithData:artworkGetResponse.artistImageData] : [UIImage imageWithData:artworkGetResponse.albumImageData];
        _imageView.backgroundColor = [UIColor clearColor];
    }
    
    NSNotification * n = notification;
    if (![n.object isKindOfClass:[NetworkAudioArtworkAvailableNotification class]])
        return;
    NetworkAudioArtworkAvailableNotification * artworkNotification = n.object;
    if (![[artworkNotification.artist lowercaseString] isEqualToString:[_label.text lowercaseString]]) return;
    _imageView.image = artworkNotification.image;
    _imageView.backgroundColor = [UIColor clearColor];
}
@end