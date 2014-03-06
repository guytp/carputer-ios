#import "AlbumTableHeaderView.h"
#import "ClientController.h"
#import "PlaylistQueueCommand.h"
#import "AppDelegate.h"
#import "AlbumListViewController.h"
#import "AudioFileFactory.h"

@implementation AlbumTableHeaderView

- (void)setupForAudioFiles:(NSArray *)audioFiles {
    // Store details
    _album = audioFiles;
    
    // Set album details
    NetworkAudioFile * audioFile = [audioFiles objectAtIndex:0];
    _albumLabel.text = audioFile.album;
    
    // Determine total duration
    int durationTotalSeconds = 0;
    for (NetworkAudioFile * audioFile in audioFiles)
        durationTotalSeconds += [audioFile.duration intValue];
    int durationTotalMinutes = durationTotalSeconds / 60;
    _summaryLabel.text = [NSString stringWithFormat:@"%lu songs %d minutes", (unsigned long)[audioFiles count], durationTotalMinutes];
    
    // Setup image
    UIImage * image = [[AudioFileFactory applicationInstance] imageForArtist:audioFile.artist album:audioFile.album];
    if (!image)
        image = [UIImage imageNamed:@"MusicFolderWooden"];
    _artworkImage.image = image;
    
}

- (IBAction)queuePlayAlbum:(id)sender {
    // Send the command to play/queue the album tracks
    NSMutableArray * audioFileIds = [NSMutableArray arrayWithCapacity:_album.count];
    for (NetworkAudioFile * audioFile in _album)
        [audioFileIds addObject:audioFile.audioFileId];
    PlaylistQueueCommand * command = [[PlaylistQueueCommand alloc] initWithAudioFileIds:audioFileIds replaceCurrentQueue:sender == _playButton];
    [[ClientController applicationInstance] sendCommand:command withTarget:self successSelector:nil failedSelector:@selector(audioPlaybackFailed)];
    
    // Now we initiate the segue to now playing if play rather than queue
    if (sender == _queueButton)
        return;
    AppDelegate * appDelegate = (AppDelegate *)[UIApplication sharedApplication].delegate;
    if ([appDelegate.window.rootViewController class] != [UITabBarController class])
        return;
    UITabBarController * tabBarController = (UITabBarController *)appDelegate.window.rootViewController;
    for (UIViewController * viewController in tabBarController.viewControllers)
    {
        if ([viewController class] != [UINavigationController class])
            continue;
        UINavigationController * navigationController = (UINavigationController *)viewController;
        for (UIViewController * vc in navigationController.viewControllers)
        {
            if ([vc class] != [AlbumListViewController class])
                continue;
            [vc performSelector:@selector(navigateToNowPlaying:) withObject:nil];
            return;
        }
    }
    return;
}

- (void)audioPlaybackFailed {
    [[[UIAlertView alloc] initWithTitle:@"Playback Problem" message:@"There was a problem starting the playback of the album you selected." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

@end