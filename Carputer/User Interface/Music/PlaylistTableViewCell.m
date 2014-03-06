#import "PlaylistTableViewCell.h"

@implementation PlaylistTableViewCell
- (NSString *)timeStringForSeconds:(int) seconds {
    int durationSeconds = seconds;
    int durationHours = durationSeconds / 3600;
    durationSeconds -= 3600 * durationHours;
    int durationMinutes = durationSeconds / 60;
    durationSeconds -= 60 * durationMinutes;
    if (durationHours > 0)
        return [NSString stringWithFormat:@"%02d:%02d:%02d", durationHours,durationMinutes, durationSeconds];
    else
        return [NSString stringWithFormat:@"%02d:%02d", durationMinutes, durationSeconds];
}

- (void)setupForAudioFile:(NetworkAudioFile *)audioFile isPlaying:(BOOL)isPlaying {
    self.backgroundColor = isPlaying ? [UIColor blackColor] : [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _audioFile = audioFile;
    _titleLabel.text = audioFile.title;
    _durationLabel.text = [self timeStringForSeconds:[audioFile.duration intValue]];
}
@end