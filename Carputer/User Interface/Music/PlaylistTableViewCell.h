#import <UIKit/UIKit.h>
#import "NetworkAudioFile.h"

@interface PlaylistTableViewCell : UITableViewCell {
    IBOutlet UILabel * _titleLabel;
    IBOutlet UILabel * _durationLabel;
    @private
    NetworkAudioFile * _audioFile;
}


- (void)setupForAudioFile:(NetworkAudioFile *)audioFile isPlaying:(BOOL)isPlaying;
@end