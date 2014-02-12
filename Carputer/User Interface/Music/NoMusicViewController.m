#import "NoMusicViewController.h"
#import "NotificationClient.h"
#import "AudioFileFactory.h"
#import "NetworkAudioLibraryUpdateNotification.h"
#import "ArtistCollectionViewController.h"

@implementation NoMusicViewController

- (void)viewDidLoad
{
    // Call to base
    [super viewDidLoad];
    
    // Update the stack within view controller to make us sole parent
    self.navigationController.viewControllers = [NSArray arrayWithObject:self];
    self.navigationController.navigationBarHidden = YES;

    // Hookup to NSNotificationCenter
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkNotification:) name:kNotificationClientNotificationName object:nil];
}

- (void)networkNotification:(NSNotification *) notification {
    // Return if its a notification we don't care about
    if (![notification.object isKindOfClass:[NetworkAudioLibraryUpdateNotification class]])
        return;
    
    // Callback on main thread if required
    if (![NSThread currentThread].isMainThread)
    {
        [self performSelectorOnMainThread:@selector(networkNotification:) withObject:notification waitUntilDone:NO];
        return;
    }
    
    // Get a list of files, if still 0 we can just return
    NSArray * audioFiles = [[AudioFileFactory applicationInstance] readAllActive];
    if (audioFiles && audioFiles.count < 1)
        return;
    
    // Update the stack to move to Artist Collection View Controller
    UIStoryboard* storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController * artistCollectionViewController = [storyBoard instantiateViewControllerWithIdentifier:@"Artists Collection"];
    self.navigationController.navigationBarHidden = NO;
    [self.navigationController setViewControllers:[NSArray arrayWithObject:artistCollectionViewController] animated:YES];
}
@end