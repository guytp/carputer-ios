#import <UIKit/UIKit.h>
#import "CommandClient.h"

@interface DebugViewController : UIViewController {
    IBOutlet UIButton *echoButton;
    IBOutlet UITextField *echoMessageTextField;
}

- (IBAction)echoPressed:(id)sender;
@end
