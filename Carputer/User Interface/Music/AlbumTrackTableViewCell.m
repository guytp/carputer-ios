#import "AlbumTrackTableViewCell.h"
#import "PlaylistQueueCommand.h"
#import "ClientController.h"

@implementation AlbumTrackTableViewCell
- (void)setupCellForAudioFile:(NetworkAudioFile *)audioFile {
    self.backgroundColor = [UIColor blackColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _audioFile = audioFile;
    _trackNumberLabel.text = [NSString stringWithFormat:@"%@", audioFile.trackNumber];
    _titleLabel.text = audioFile.title;
    int durationSeconds = [audioFile.duration intValue];
    int durationHours = durationSeconds / 3600;
    durationSeconds -= 3600 * durationHours;
    int durationMinutes = durationSeconds / 60;
    durationSeconds -= 60 * durationMinutes;
    if (durationHours > 0)
        _durationLabel.text = [NSString stringWithFormat:@"%02d:%02d:%02d", durationHours,durationMinutes, durationSeconds];
    else
        _durationLabel.text = [NSString stringWithFormat:@"%02d:%02d", durationMinutes, durationSeconds];
}

- (IBAction)queuePressed:(id)sender {
    // Determine the audio file for this item and play it wiping existing queue
    PlaylistQueueCommand * command = [[PlaylistQueueCommand alloc] initWithAudioFileIds:[NSArray arrayWithObject:_audioFile.audioFileId] replaceCurrentQueue:NO];
    [[ClientController applicationInstance] sendCommand:command withTarget:self successSelector:nil failedSelector:@selector(audioPlaybackFailed)];
    return;
}

- (void)audioPlaybackFailed {
    [[[UIAlertView alloc] initWithTitle:@"Playback Problem" message:@"There was a problem starting the playback of the track you selected." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}
@end