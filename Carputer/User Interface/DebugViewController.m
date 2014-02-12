#import "DebugViewController.h"
#import "EchoCommand.h"
#import "ClientController.h"
#import "CommandClientResponse.h"
#import "ArtworkGetCommand.h"
#import "ArtworkGetResponse.h"

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

- (IBAction)getArtworkPressed:(id)sender {
    ClientController * clientController = [ClientController applicationInstance];
    if (!clientController.hasConnectedClients)
    {
        [self showMessage:@"No clients connected"];
        return;
    }
    
    // Error check
    BOOL getArtist = sender == _getArtistArtworkButton || sender == _getAllArtworkButton;
    BOOL getAlbum = sender == _getAlbumArtworkButton || sender == _getAllArtworkButton;
    if ((!getArtist) && (!getAlbum)) {
        [self showMessage:@"You didn't select any artwork to retrieve"];
        return;
    }
    if ((getArtist) && ((!getArtworkArtistTextField.text) || (getArtworkArtistTextField.text.length < 1)))
    {
        [self showMessage:@"You must enter an artist"];
        return;
    }
    if ((getAlbum) && ((!getArtworkAlbumTextField.text) || (getArtworkAlbumTextField.text.length < 1)))
    {
        [self showMessage:@"You must enter an album"];
        return;
    }
    
    // Perform the request
    ArtworkGetCommand * command;
    if ((getAlbum) && (!getArtist))
        command = [[ArtworkGetCommand alloc] initWithArtist:getArtworkArtistTextField.text album:getArtworkAlbumTextField.text getArtistImage:NO];
    else if ((getAlbum) && (getArtist))
        command = [[ArtworkGetCommand alloc] initWithArtist:getArtworkArtistTextField.text album:getArtworkAlbumTextField.text getArtistImage:YES];
    else
        command = [[ArtworkGetCommand alloc] initWithArtist:getArtworkArtistTextField.text];
    [clientController sendCommand:command withTarget:self successSelector:@selector(artworkGetSuccess:) failedSelector:@selector(echoFailed:)];
}

- (void)showMessage:(NSString *)message {
    if (![NSThread isMainThread])
    {
        [self performSelectorOnMainThread:@selector(showMessage:) withObject:message waitUntilDone:NO];
        return;
    }
    [[[UIAlertView alloc] initWithTitle:@"Carputer" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}

- (void)artworkGetSuccess:(CommandClientResponse *)response {
    ArtworkGetResponse * r = response.response;
    if (r.requestedArtist)
        [self showMessage:[NSString stringWithFormat:@"Artwork Response\r\nArtist Available: %@\r\nArtist Image: %d bytes",
                           (!r.artistImageAvailable ? @"Not checked" :
                            [r.artistImageAvailable boolValue] ? @"Yes" : @"No"), r.artistImageData.length]];
    if (r.requestedAlbum)
        [self showMessage:[NSString stringWithFormat:@"Album Response\r\nAlbum Available: %@\r\nAlbum Image: %d bytes",
                           (!r.albumImageAvailable ? @"Not checked" :
                            [r.albumImageAvailable boolValue] ? @"Yes" : @"No"), r.albumImageData.length]];
}

- (void)echoSuccess:(CommandClientResponse *)response {
    [self showMessage:[NSString stringWithFormat:@"%@ says %@", response.client.hostname, (NSString *)response.response]];
}

- (void)echoFailed:(NSError *)error {
    NSLog(@"%@", error);
    [self showMessage:@"An error occurred whilst processing the request."];
}
@end