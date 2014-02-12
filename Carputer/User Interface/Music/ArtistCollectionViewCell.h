#import <UIKit/UIKit.h>

@interface ArtistCollectionViewCell : UICollectionViewCell {
    IBOutlet UIImageView * _imageView;
    IBOutlet UILabel * _label;
    @private
    BOOL _registeredNotifications;
}

@property (strong, readonly) NSString * label;

- (void)setupForArtist:(NSString *)artist withImage:(UIImage *)image;
@end