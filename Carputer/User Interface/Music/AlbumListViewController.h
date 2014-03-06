#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "BDKCollectionIndexView.h"

@interface AlbumListViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate> {
@private
    NSArray * _dataSource;
    NSString * _artist;
    BDKCollectionIndexView * _indexView;
}

@property (strong, atomic) NSString * artist;
@property (strong, nonatomic) BDKCollectionIndexView *indexView;

- (IBAction)navigateToNowPlaying:(id)sender;
@end