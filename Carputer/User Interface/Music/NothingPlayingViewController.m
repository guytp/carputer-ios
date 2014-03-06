#import "NothingPlayingViewController.h"
#import "NotificationClient.h"
#import "NetworkAudioStatusNotification.h"


@interface NothingPlayingViewController ()
- (void)processNotification:(NetworkAudioStatusNotification *)notification;
@end

@implementation NothingPlayingViewController
- (void)viewDidAppear:(BOOL)animated {
    _hasDisplayed = YES;
}

- (void)viewDidLoad {
    // Read last notification
    NetworkAudioStatusNotification * lastNotification = [NotificationClient lastNotificationOfType:@"NetworkAudioStatusNotification"];
    _parseNotifications = YES;
    [self processNotification:lastNotification];
}

- (void)viewWillAppear:(BOOL)animated {
    // Hookup to NSNotificationCenter
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkNotification:) name:kNotificationClientNotificationName object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)networkNotification:(NSNotification *) notification {
    // Return if its a notification we don't care about
    if (![notification.object isKindOfClass:[NetworkAudioStatusNotification class]])
        return;
    [self processNotification:notification.object];
}

- (void)processNotification:(NetworkAudioStatusNotification *)status {
    // Ignore if we're not parsing these
    if (!_parseNotifications)
        return;
    
    // Callback to UI
    if (![NSThread currentThread].isMainThread)
    {
        [self performSelectorOnMainThread:@selector(processNotification:) withObject:status waitUntilDone:NO];
        return;
    }
    
    // If we have something playing then segue to the now playing view
    if ((status) && (status.playlist) && ([status.playlist count] > 0))
    {
        if (!_hasDisplayed)
            return;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        _parseNotifications = NO;
        UIStoryboard* storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
        UIViewController * nowPlaying = [storyBoard instantiateViewControllerWithIdentifier:@"Now Playing"];
        NSMutableArray * viewControllers = [NSMutableArray array];
        for (UIViewController * controller in self.navigationController.viewControllers)
            if (controller != self)
                [viewControllers addObject:controller];
        [viewControllers addObject:nowPlaying];
        [self.navigationController setViewControllers:viewControllers animated:YES];
    }
}
@end