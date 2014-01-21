#import <UIKit/UIKit.h>
#import "BDKCollectionIndexView.h"

@interface ArtistCollectionViewController : UICollectionViewController <UICollectionViewDataSource, UICollectionViewDelegate> {
    @private
    NSMutableArray * _dataSource;
    BDKCollectionIndexView * _indexView;
}


@property (strong, nonatomic) BDKCollectionIndexView *indexView;

- (IBAction)navigateToNowPlaying:(id)sender;
@end