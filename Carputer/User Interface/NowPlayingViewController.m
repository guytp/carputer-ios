#import "NowPlayingViewController.h"
#import "NotificationClient.h"
#import "NetworkAudioStatusNotification.h"
#import "ClientController.h"
#import "PauseToggleCommand.h"
#import "PlaylistJumpCommand.h"
#import "AudioFile.h"
#import "AudioFileFactory.h"
#import "PlaylistTableViewCell.h"
#import "TrackJumpCommand.h"
#import "PlaylistNextCommand.h"
#import "PlaylistPreviousCommand.h"
#import "ToggleShuffleCommand.h"
#import "ToggleRepeatCommand.h"
#import "AudioFileFactory.h"

@interface NowPlayingViewController ()
- (NSString *)timeStringForSeconds:(int)seconds;
- (void)processNotification:(NetworkAudioStatusNotification *)notification;
@end

@implementation NowPlayingViewController
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidAppear:(BOOL)animated {
    _hasDisplayed = YES;
}

- (void)viewDidLoad {
    // Clear toolbar by default to setup with notifications
    [_toolbar setItems:[NSArray array]];

    // Read last notification
    NetworkAudioStatusNotification * lastNotification = [NotificationClient lastNotificationOfType:@"NetworkAudioStatusNotification"];
    _parseNotifications = YES;
    [self processNotification:lastNotification];
    
    // Hookup to NSNotificationCenter
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkNotification:) name:kNotificationClientNotificationName object:nil];
    
    // Setup some defaults
    _isScrubDown = NO;
}

- (void)networkNotification:(NSNotification *) notification {
    // Return if its a notification we don't care about
    if (![notification.object isKindOfClass:[NetworkAudioStatusNotification class]])
        return;
    [self processNotification:notification.object];
}

- (void)processNotification:(NetworkAudioStatusNotification *)status {
    // Ignore if we're not parsing these
    if ((!_parseNotifications) || ([status class] != [NetworkAudioStatusNotification class]))
        return;
    
    // Callback to UI
    if (![NSThread currentThread].isMainThread)
    {
        [self performSelectorOnMainThread:@selector(processNotification:) withObject:status waitUntilDone:NO];
        return;
    }
    
    // Store playlist
    bool playlistChanged = ((!_playlist) || (!status) || ([_playlist count] != status.playlist.count));
    if (!playlistChanged)
    {
        // Compare the two lists
        bool didntFind = false;
        for (int i = 0; i < [status.playlist count]; i++)
        {
            AudioFile * af1 = [status.playlist objectAtIndex:i];
            AudioFile * af2 = [_playlist objectAtIndex:i];
            if ([af1.id intValue] != [af2.id intValue])
            {
                didntFind = true;
                break;
            }
        }
        if (didntFind)
            playlistChanged = true;
    }
    BOOL reloadTableView = NO;
    if (playlistChanged)
    {
        _playlist = status ? status.playlist : [NSArray array];
        reloadTableView = YES;
    }
    
    // If we have nothing playing then segue to the nothing playing view
    if ((!_playlist) || ([_playlist count] == 0))
    {
        if (!_hasDisplayed)
            return;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        _parseNotifications = NO;
        
        UIStoryboard* storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController * nothingPlaying = [storyBoard instantiateViewControllerWithIdentifier:@"Nothing Playing"];
        NSMutableArray * viewControllers = [NSMutableArray array];
        for (UIViewController * controller in self.navigationController.viewControllers)
            if (controller != self)
                [viewControllers addObject:controller];
        [viewControllers addObject:nothingPlaying];
        NSLog(@"View Controllers: %@", viewControllers);
        [self.navigationController setViewControllers:viewControllers animated:YES];
        
        return;
    }
    

    // Update the view for current track
    AudioFile * thisTrack = nil;
    if ((status.playlist) && ([status.playlist count] >= status.playlistPosition + 1))
        thisTrack = [status.playlist objectAtIndex:status.playlistPosition];
    if ((thisTrack) && ([_audioTrack.id intValue] != [thisTrack.id intValue]))
    {
        _currentTrack = status.playlistPosition;
        _audioTrack = thisTrack;
        self.title = [NSString stringWithFormat:@"%@ - %@", _audioTrack.artist, _audioTrack.title];
        _titleLabel.text = _audioTrack.title;
        _durationLabel.text = [self timeStringForSeconds:status.duration];
        _durationSlider.maximumValue = status.duration;
        reloadTableView = YES;
        UIImage * image = [[AudioFileFactory applicationInstance] imageForArtist:thisTrack.artist album:thisTrack.album];
        if (!image)
            image = [UIImage imageNamed:@"MusicFolderWooden"];
        _artworkImageView.image = image;
    }
    _durationLabel.text = [self timeStringForSeconds:status.duration == 0 ? [thisTrack.duration intValue] : status.duration];
    if (!_isScrubDown)
    {
        _durationSlider.maximumValue = status.duration;
        _durationSlider.userInteractionEnabled = (_durationSlider.maximumValue > 0);
    }
    _previousTrackButton.enabled = status.canMovePrevious;
    _nextTrackButton.enabled = status.canMoveNext;
    BOOL isPlayVisible = [_toolbar.items containsObject:_playButton];
    BOOL shouldPlayBeVisible = status.isPaused || !status.isPlaying;
    BOOL isPauseVisible = [_toolbar.items containsObject:_pauseButton];
    BOOL shouldPauseBeVisible = status.isPlaying && !status.isPaused;
    if (!isPlayVisible && shouldPlayBeVisible)
        [_toolbar setItems:[NSArray arrayWithObjects:_barSpace1, _previousTrackButton, _barSpace2, _playButton, _barSpace3, _nextTrackButton, _barSpace4, _repeatButton, _shuffleButton, nil]];
    else if (!isPauseVisible && shouldPauseBeVisible)
        [_toolbar setItems:[NSArray arrayWithObjects:_barSpace1, _previousTrackButton, _barSpace2, _pauseButton, _barSpace3, _nextTrackButton, _barSpace4, _repeatButton, _shuffleButton, nil]];
    if (!_isScrubDown)
    {
        _durationSlider.value = status.position;
        _progressLabel.text = [self timeStringForSeconds:status.position];
    }
    _shuffleButton.tintColor = status.isShuffle ? [UIColor redColor] : nil;
    _repeatButton.tintColor = status.isRepeatAll ? [UIColor redColor] : nil;
    if (reloadTableView)
        [_playlistTableView reloadData];
}

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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PlaylistTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"PlaylistCell" forIndexPath:indexPath];
    [cell setupForAudioFile:[_playlist objectAtIndex:indexPath.row] isPlaying:indexPath.row == _currentTrack];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _playlist.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[ClientController applicationInstance] sendAudioCommand:[[PlaylistJumpCommand alloc] initWithPosition:(int)indexPath.row] withTarget:self successSelector:nil failedSelector:@selector(actionFailed:)];
}


- (IBAction)playPauseToggle:(id)sender {
    [[ClientController applicationInstance] sendAudioCommand:[[PauseToggleCommand alloc] init] withTarget:self successSelector:nil failedSelector:@selector(actionFailed:)];
}

- (void)actionFailed:(NSError *)error {
    NSLog(@"Pause failed: %@", error);
    [[[UIAlertView alloc] initWithTitle:@"Oops" message:@"Sorry your last request failed, please try again or report this error." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (IBAction)movePrevious:(id)sender
{
    [[ClientController applicationInstance] sendAudioCommand:[[PlaylistPreviousCommand alloc] init] withTarget:self successSelector:nil failedSelector:@selector(actionFailed:)];
}

- (IBAction)moveNext:(id)sender
{
    [[ClientController applicationInstance] sendAudioCommand:[[PlaylistNextCommand alloc] init] withTarget:self successSelector:nil failedSelector:@selector(actionFailed:)];
}

- (IBAction)scrubTouchDown:(id)sender {
    _isScrubDown = YES;
    _lastDragSlider = [NSDate date];
}

- (IBAction)scrubTouchUpInside:(id)sender {
    [self scrubDrag:sender];
    _isScrubDown = NO;  
}

- (IBAction)scrubDrag:(id)sender {
    int duration = (int)_durationSlider.value;
    _progressLabel.text = [self timeStringForSeconds:duration];
    if ([_lastDragSlider timeIntervalSinceNow] > -0.25)
        return;
    _lastDragSlider = [NSDate date];
    [[ClientController applicationInstance] sendAudioCommand:[[TrackJumpCommand alloc] initWithOffset:duration] withTarget:self successSelector:nil failedSelector:@selector(actionFailed:)];
}

- (IBAction)scrubTouchUpOutside:(id)sender {
    _isScrubDown = NO;
}

- (IBAction)toggleShuffle:(id)sender {
    [[ClientController applicationInstance] sendAudioCommand:[[ToggleShuffleCommand alloc] init] withTarget:self successSelector:nil failedSelector:@selector(actionFailed:)];
}

- (IBAction)toggleRepeat:(id)sender {
    [[ClientController applicationInstance] sendAudioCommand:[[ToggleRepeatCommand alloc] init] withTarget:self successSelector:nil failedSelector:@selector(actionFailed:)];
}
@end