#import <UIKit/UIKit.h>
#import "CommandClient.h"

@interface DebugViewController : UIViewController {
    IBOutlet UIButton *echoButton;
    IBOutlet UITextField *echoMessageTextField;
    IBOutlet UIButton * _getArtistArtworkButton;
    IBOutlet UIButton * _getAlbumArtworkButton;
    IBOutlet UIButton * _getAllArtworkButton;
    IBOutlet UITextField *getArtworkArtistTextField;
    IBOutlet UITextField *getArtworkAlbumTextField;
}

- (IBAction)echoPressed:(id)sender;
- (IBAction)getArtworkPressed:(id)sender;
@end
