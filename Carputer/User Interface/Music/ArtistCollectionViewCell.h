#import <UIKit/UIKit.h>

@interface ArtistCollectionViewCell : UICollectionViewCell {
    IBOutlet UIImageView * _imageView;
    IBOutlet UILabel * _label;
}

@property (strong, readonly) NSString * label;

- (void)setupForArtist:(NSString *)artist withImage:(UIImage *)image;
@end