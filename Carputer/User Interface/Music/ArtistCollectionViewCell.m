#import "ArtistCollectionViewCell.h"

@implementation ArtistCollectionViewCell

- (NSString *)label {
    return _label.text;
}

- (void)setupForArtist:(NSString *)artist withImage:(UIImage *)image {
    // Setup views from details supplied
    _label.text = artist;
    _label.numberOfLines = 0;
    CGSize size = [_label sizeThatFits:CGSizeMake(200, 70)];
    _label.frame = CGRectMake(_label.frame.origin.x, _label.frame.origin.y, 200, size.height);
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
@end