#import "NoMusicViewController.h"

@implementation NoMusicViewController

- (void)viewDidLoad
{
    // Call to base
    [super viewDidLoad];
    
    // Update the stack within view controller to make us sole parent
    self.navigationController.viewControllers = [NSArray arrayWithObject:self];
    self.navigationController.navigationBarHidden = YES;
}
@end