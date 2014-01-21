#import <UIKit/UIKit.h>
#import "AudioFile.h"

@interface AlbumTrackTableViewCell : UITableViewCell {
    IBOutlet UILabel * _trackNumberLabel;
    IBOutlet UILabel * _titleLabel;
    IBOutlet UILabel * _durationLabel;
    @private
    AudioFile * _audioFile;
}

- (void)setupCellForAudioFile:(AudioFile *)audioFile;

- (IBAction)queuePressed:(id)sender;
@end