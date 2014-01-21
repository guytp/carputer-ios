#import <UIKit/UIKit.h>

@interface CollectionSectionHeaderView : UICollectionReusableView {
    IBOutlet UILabel * _titleLabel;
    @private
    NSString * _title;
}

@property (strong) NSString * title;

@end