#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface AlbumListViewController : UITableViewController <UITableViewDataSource, UITableViewDelegate> {
@private
    NSMutableArray * _dataSource;
    NSString * _artist;
}

@property (strong, atomic) NSString * artist;

- (IBAction)navigateToNowPlaying:(id)sender;
@end