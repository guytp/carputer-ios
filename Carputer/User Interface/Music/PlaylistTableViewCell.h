#import <UIKit/UIKit.h>
#import "AudioFile.h"

@interface PlaylistTableViewCell : UITableViewCell {
    IBOutlet UILabel * _titleLabel;
    IBOutlet UILabel * _durationLabel;
    @private
    AudioFile * _audioFile;
}


- (void)setupForAudioFile:(AudioFile *)audioFile isPlaying:(BOOL)isPlaying;
@end