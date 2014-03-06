#import <UIKit/UIKit.h>
@class NetworkAudioFile;

@interface NowPlayingViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
{
    IBOutlet UISlider * _durationSlider;
    IBOutlet UILabel * _durationLabel;
    IBOutlet UILabel * _progressLabel;
    IBOutlet UILabel * _titleLabel;
    IBOutlet UITableView * _playlistTableView;
    IBOutlet UIBarButtonItem * _pauseButton;
    IBOutlet UIBarButtonItem * _playButton;
    IBOutlet UIBarButtonItem * _previousTrackButton;
    IBOutlet UIBarButtonItem * _nextTrackButton;
    IBOutlet UIBarButtonItem * _barSpace1;
    IBOutlet UIBarButtonItem * _barSpace2;
    IBOutlet UIBarButtonItem * _barSpace3;
    IBOutlet UIBarButtonItem * _barSpace4;
    IBOutlet UIBarButtonItem * _shuffleButton;
    IBOutlet UIBarButtonItem * _repeatButton;
    IBOutlet UIToolbar * _toolbar;
    IBOutlet UIImageView * _artworkImageView;
    @private
    NSDate * _lastDragSlider;
    NetworkAudioFile * _audioTrack;
    NSArray * _playlist;
    int _currentTrack;
    int _isScrubDown;
    BOOL _parseNotifications;
    BOOL _hasDisplayed;
}

- (IBAction)playPauseToggle:(id)sender;

- (IBAction)movePrevious:(id)sender;
- (IBAction)moveNext:(id)sender;

- (IBAction)scrubTouchDown:(id)sender;
- (IBAction)scrubTouchUpInside:(id)sender;
- (IBAction)scrubTouchUpOutside:(id)sender;
- (IBAction)scrubDrag:(id)sender;

- (IBAction)toggleShuffle:(id)sender;
- (IBAction)toggleRepeat:(id)sender;
@end