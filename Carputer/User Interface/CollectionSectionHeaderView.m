#import "CollectionSectionHeaderView.h"

@implementation CollectionSectionHeaderView

- (void)setTitle:(NSString *)title {
    _titleLabel.text = title;
}

- (NSString *)title {
    return _titleLabel.text;
}
@end
