#import <UIKit/UIKit.h>
#import "NetworkAudioFile.h"

@interface AlbumTrackTableViewCell : UITableViewCell {
    IBOutlet UILabel * _trackNumberLabel;
    IBOutlet UILabel * _titleLabel;
    IBOutlet UILabel * _durationLabel;
    @private
    NetworkAudioFile * _audioFile;
}

- (void)setupCellForAudioFile:(NetworkAudioFile *)audioFile;

- (IBAction)queuePressed:(id)sender;
@end