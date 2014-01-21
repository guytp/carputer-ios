#import "DebugViewController.h"
#import "EchoCommand.h"
#import "ClientController.h"
#import "CommandClientResponse.h"

@interface DebugViewController ()
- (void)showMessage:(NSString *)message;
@end

@implementation DebugViewController

- (IBAction)echoPressed:(id)sender {
    ClientController * clientController = [ClientController applicationInstance];
    if (!clientController.hasConnectedClients)
    {
        [self showMessage:@"No clients connected"];
        return;
    }
    
    EchoCommand * echoCommand = [[EchoCommand alloc] initWithMessage:echoMessageTextField.text];
    [clientController sendCommand:echoCommand withTarget:self successSelector:@selector(echoSuccess:) failedSelector:@selector(echoFailed:)];
}

- (void)showMessage:(NSString *)message {
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(showMessage:) withObject:message waitUntilDone:NO];
        return;
    }
    [[[UIAlertView alloc] initWithTitle:@"Carputer" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)echoSuccess:(CommandClientResponse *)response {
    [self showMessage:[NSString stringWithFormat:@"%@ says %@", response.client.hostname, (NSString *)response.response]];
}

- (void)echoFailed:(NSError *)error {
    NSLog(@"%@", error);
    [self showMessage:@"An error occurred whilst processing the echo request."];
}
@end