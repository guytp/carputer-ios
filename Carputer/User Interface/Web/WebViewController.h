#import <Foundation/Foundation.h>

@interface WebViewController : UIViewController <UIWebViewDelegate> {
    IBOutlet UIWebView * _webView;
    IBOutlet UITextField * _mainInput;
    IBOutlet UILabel * _status;
    IBOutlet UIActivityIndicatorView * _activityIndicator;
    IBOutlet UIButton * _backButton;
    IBOutlet UIButton * _forwardButton;
    IBOutlet UIButton * _cancelButton;
    IBOutlet UIButton * _reloadButton;
    @private
    NSString * _originalText;
    BOOL _isContentLoaded;
}

- (IBAction)previousPressed:(id)sender;
- (IBAction)forwardPressed:(id)sender;
- (IBAction)reloadPressed:(id)sender;
- (IBAction)cancelPressed:(id)sender;
@end