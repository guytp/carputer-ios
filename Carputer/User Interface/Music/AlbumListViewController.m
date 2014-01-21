#import "AlbumListViewController.h"
#import "AudioFile.h"
#import "AudioFileFactory.h"
#import "AlbumTrackTableViewCell.h"
#import "AlbumTableHeaderView.h"
#import "PlaylistQueueCommand.h"
#import "ClientController.h"
#import "NetworkAudioStatusNotification.h"
#import "NotificationClient.h"

@implementation AlbumListViewController 

- (void)setArtist:(NSString *)artist
{
    self.tableView.backgroundColor = [UIColor blackColor];

    @synchronized (_dataSource)
    {
        // Store artist
        _artist = artist;
        
        // Set the title of the navigation bar
        self.navigationItem.title = artist;
        
        // Get list of albums and separate into an array of arrays with each array
        // being a single album
        _dataSource = [NSMutableArray array];
        NSArray * audioFiles = [[AudioFileFactory applicationInstance] readAllActiveForArtist:artist];
        NSString * lastAlbum;
        NSMutableArray * thisAlbumTracks;
        for (AudioFile * audioFile in audioFiles)
        {
            // On album change add a new entry
            if (![audioFile.album isEqualToString:lastAlbum])
            {
                lastAlbum = audioFile.album;
                thisAlbumTracks = [NSMutableArray array];
                [_dataSource addObject:thisAlbumTracks];
            }
            
            // Add the item to this album
            [thisAlbumTracks addObject:audioFile];
        }
    }
    
    // Tell the table to reload
    self.tableView.allowsSelection = YES;
    [self.tableView reloadData];
}

- (NSString *)artist
{
    @synchronized (_dataSource)
    {
        return _artist;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    AlbumTrackTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"AlbumListTrackCellView" forIndexPath:indexPath];
    AudioFile * audioFile = ((AudioFile *)[[_dataSource objectAtIndex:indexPath.section] objectAtIndex:indexPath.row]);
    [cell setupCellForAudioFile:audioFile];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [_dataSource count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[_dataSource objectAtIndex:section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return ((AudioFile *)[[_dataSource objectAtIndex:section] objectAtIndex:0]).album;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    NSArray *topLevelObjects = [[NSBundle mainBundle] loadNibNamed:@"AlbumTableHeaderView" owner:self options:nil];
    AlbumTableHeaderView * header = [topLevelObjects objectAtIndex:0];
    [header setupForAudioFiles:[_dataSource objectAtIndex:section]];
    return header;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 170;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 5;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Determine the audio file for this item and play it wiping existing queue
    AudioFile * audioFile = [[_dataSource objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    PlaylistQueueCommand * command = [[PlaylistQueueCommand alloc] initWithAudioFileIds:[NSArray arrayWithObject:audioFile.id] replaceCurrentQueue:YES];
    [[ClientController applicationInstance] sendAudioCommand:command withTarget:self successSelector:nil failedSelector:@selector(audioPlaybackFailed)];
    return indexPath;
}

- (void)audioPlaybackFailed {
    [[[UIAlertView alloc] initWithTitle:@"Playback Problem" message:@"There was a problem starting the playback of the track you selected." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (IBAction)navigateToNowPlaying:(id)sender {
    NetworkAudioStatusNotification * lastNotification = [NotificationClient lastNotificationOfType:@"NetworkAudioStatusNotification"];
    bool isMusicPlaying = lastNotification && lastNotification.playlist && lastNotification.playlist.count > 0;
    UIStoryboard* storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController * viewController = [storyBoard instantiateViewControllerWithIdentifier:isMusicPlaying ? @"Now Playing" : @"Nothing Playing"];
    [self.navigationController pushViewController:viewController animated:YES];
}
@end