#import <UIKit/UIKit.h>

@interface CollectionSectionHeaderView : UICollectionReusableView {
    IBOutlet UILabel * _titleLabel;
}

@property (strong) NSString * title;

@end