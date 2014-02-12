#import "ArtistCollectionViewController.h"
#import "ArtistCollectionViewCell.h"
#import "CollectionSectionHeaderView.h"
#import "AudioFileFactory.h"
#import "AudioFile.h"
#import "NSDictionary+Dictionary_ContainsKey.h"
#import "AlbumListViewController.h"
#import "NotificationClient.h"
#import "NetworkAudioStatusNotification.h"
#import "NetworkAudioLibraryUpdateNotification.h"

@interface ArtistCollectionViewController()
- (void) updateDataSource;
@end

@implementation ArtistCollectionViewController

@synthesize indexView = _indexView;


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)viewWillAppear:(BOOL)animated {
    // Get a handle to audio data and parse out for displaying in table
    [self updateDataSource];
}

- (void)viewDidLoad {
    // Add index view
    [self.view addSubview:self.indexView];

    // Hookup to NSNotificationCenter
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkNotification:) name:kNotificationClientNotificationName object:nil];
}

- (void)networkNotification:(NSNotification *) notification {
    // Return if its a notification we don't care about
    if (![notification.object isKindOfClass:[NetworkAudioLibraryUpdateNotification class]])
        return;
    [self updateDataSource];
}


- (void) updateDataSource {
    // Callback to UI if required
    if (![NSThread currentThread].isMainThread)
    {
        [self performSelectorOnMainThread:@selector(updateDataSource) withObject:nil waitUntilDone:NO];
        return;
    }
    
    // If data source doesn't exist create it, otherwise clear it
    if (!_dataSource)
        _dataSource = [NSMutableArray array];
    else
        [_dataSource removeAllObjects];
    
    NSArray * audioFiles = [[AudioFileFactory applicationInstance] readAllActive];
    NSString * lastLetter;
    NSMutableArray * indexSections = [NSMutableArray array];
    for (AudioFile * audioFile in audioFiles)
    {
        // Determine first letter and if this is not in the dictionary hash add it now
        NSString * artistFirstLetter = [[audioFile.artist substringToIndex:1] uppercaseString];
        NSMutableArray * letterArray = nil;
        if (![lastLetter isEqualToString:artistFirstLetter])
        {
            letterArray = [NSMutableArray array];
            [_dataSource addObject:letterArray];
            [indexSections addObject:artistFirstLetter];
        }
        else
            letterArray = [_dataSource lastObject];
        lastLetter = artistFirstLetter;
        
        // Check if this artist is already contained, if not add them now
        if (![[[letterArray lastObject] uppercaseString] isEqualToString:[audioFile.artist uppercaseString]])
            [letterArray addObject:audioFile.artist];
    }
    self.indexView.indexTitles = indexSections;
    
    // Instruct view to reload
    [self.collectionView reloadData];
    
    // If we have no data then move to no music scene
    if (_dataSource.count < 1)
        [self performSegueWithIdentifier:@"noMusicDetected" sender:self];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [_dataSource count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [[_dataSource objectAtIndex:section] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSString * artist = [[_dataSource objectAtIndex:indexPath.section] objectAtIndex:indexPath.row];
    ArtistCollectionViewCell * cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"ArtistCollectionViewCell" forIndexPath:indexPath];
    [cell setupForArtist:artist withImage:[[AudioFileFactory applicationInstance] imageForArtist:artist]];
    return cell;
}

-(UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (![kind isEqual:UICollectionElementKindSectionHeader])
        return nil;

    CollectionSectionHeaderView * header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"CollectionSectionHeader" forIndexPath:indexPath];
    header.title = [[[_dataSource objectAtIndex:indexPath.section] firstObject] substringToIndex:1];
    return header;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"noMusicDetected"])
        return;
    
    if ([segue.destinationViewController class] == [AlbumListViewController class])
    {
        ArtistCollectionViewCell * cell = (ArtistCollectionViewCell *)sender;
        [((AlbumListViewController *)segue.destinationViewController) setArtist:cell.label];
    }
}

- (BDKCollectionIndexView *)indexView {
    if (_indexView) return _indexView;
    CGRect frame = CGRectMake(CGRectGetWidth(self.collectionView.frame) - 28,
                              CGRectGetMinY(self.collectionView.frame) + 67,
                              28,
                              CGRectGetHeight(self.collectionView.frame) - 124);
    _indexView = [BDKCollectionIndexView indexViewWithFrame:frame indexTitles:@[]];
    _indexView.autoresizingMask = (UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin);
    [_indexView addTarget:self action:@selector(indexViewValueChanged:) forControlEvents:UIControlEventValueChanged];
    return _indexView;
}


- (void)indexViewValueChanged:(BDKCollectionIndexView *)sender {
    NSIndexPath *path = [NSIndexPath indexPathForItem:0 inSection:sender.currentIndex];
    if (![self collectionView:self.collectionView cellForItemAtIndexPath:path])
        return;
    
    [self.collectionView scrollToItemAtIndexPath:path atScrollPosition:UICollectionViewScrollPositionTop animated:YES];
    CGFloat yOffset = self.collectionView.contentOffset.y;
    
    self.collectionView.contentOffset = CGPointMake(self.collectionView.contentOffset.x, yOffset);
}

- (IBAction)navigateToNowPlaying:(id)sender {
    NetworkAudioStatusNotification * lastNotification = [NotificationClient lastNotificationOfType:@"NetworkAudioStatusNotification"];
    bool isMusicPlaying = lastNotification && lastNotification.playlist && lastNotification.playlist.count > 0;
    UIStoryboard* storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController * viewController = [storyBoard instantiateViewControllerWithIdentifier:isMusicPlaying ? @"Now Playing" : @"Nothing Playing"];
    [self.navigationController pushViewController:viewController animated:YES];
}
@end