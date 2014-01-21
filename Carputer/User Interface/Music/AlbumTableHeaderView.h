#import <UIKit/UIKit.h>

@interface AlbumTableHeaderView : UIView {
    IBOutlet UILabel * _albumLabel;
    IBOutlet UIImageView * _artworkImage;
    IBOutlet UILabel * _summaryLabel;
    IBOutlet UIButton * _queueButton;
    IBOutlet UIButton * _playButton;
    @private
    NSArray * _album;
}

- (void)setupForAudioFiles:(NSArray *)audioFiles;

- (IBAction)queuePlayAlbum:(id)sender;
@end