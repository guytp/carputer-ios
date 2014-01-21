#import <UIKit/UIKit.h>
#import "NetworkSupport/ClientController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, ClientControllerDelegate> {
    @private
    ClientController * _clientController;
}

@property (strong, nonatomic) UIWindow *window;

@end