#import "WebViewController.h"

@implementation WebViewController
- (void)viewDidLoad {
    UIColor * color = [UIColor whiteColor];
    _mainInput.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_mainInput.placeholder attributes:@{NSForegroundColorAttributeName: color}];
    
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    // Remove keyboard
    [textField resignFirstResponder];
    
    // If this is a null or empty input just do nothing
    NSString * url = _mainInput.text;
    if ((!url) || (url.length < 1))
        return YES;
    
    // Determine if we think this is a URL or whether it is a search query
    NSString * lowercaseUrl = [url lowercaseString];
    BOOL isUrl = NO;
    if (([lowercaseUrl hasPrefix:@"http://"]) && ([lowercaseUrl hasPrefix:@"https://"]))
        isUrl = YES;
    if (!isUrl) {
        NSCharacterSet * periodSet = [NSCharacterSet characterSetWithCharactersInString:@"."];
        
        NSRange rangePeriod = [lowercaseUrl rangeOfCharacterFromSet:periodSet];
        NSRange rangeWhitespace = [lowercaseUrl rangeOfCharacterFromSet:[NSCharacterSet whitespaceCharacterSet]];
        isUrl = ((rangePeriod.location != NSNotFound) && (rangeWhitespace.location == NSNotFound));
    }
    
    // Kick-off the web view loading
    if ((isUrl) && (![lowercaseUrl hasPrefix:@"http://"]) && (![lowercaseUrl hasPrefix:@"https://"]))
        url = [NSString stringWithFormat:@"http://%@", url];
    if (!isUrl)
        url = [NSString stringWithFormat:@"https://www.google.co.uk/search?q=%@", [url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [_webView stopLoading];
    [_webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:url]]];
    
    // Return a yes
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    _originalText = textField.text;
    textField.text = @"";
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    if (textField.text.length == 0) {
        textField.text = _originalText;
    }
}

- (void)webViewDidStartLoad:(UIWebView *)webView {
    // Enable activity indicator
    [_activityIndicator startAnimating];
    
    // Set status bar to "Loading"
    _status.text = @"Loading...";
    
    // Show cancel and hide reload
    _cancelButton.hidden = NO;
    _reloadButton.hidden = YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView {
    // Disable activity indicator
    [_activityIndicator stopAnimating];
    
    // Set the title for the page
    NSString * title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    if ((!title) || (title.length < 1))
        title = webView.request.URL.absoluteString;;
    _status.text = title;
    _mainInput.text = webView.request.URL.absoluteString;
    _isContentLoaded = YES;

    // Update button states
    _backButton.enabled = webView.canGoBack;
    _forwardButton.enabled = webView.canGoForward;
    _cancelButton.hidden = YES;
    _reloadButton.hidden = !_isContentLoaded;
    
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    // Disable activity indicator
    [_activityIndicator stopAnimating];
    
    // Set the title for the page
    NSString * title = [webView stringByEvaluatingJavaScriptFromString:@"document.title"];
    if ((!title) || (title.length < 1))
        title = webView.request.URL.absoluteString;;
    _status.text = title;
    _mainInput.text = webView.request.URL.absoluteString;
    
    // Update button states
    _backButton.enabled = webView.canGoBack;
    _forwardButton.enabled = webView.canGoForward;
    _cancelButton.hidden = YES;
    _reloadButton.hidden = !_isContentLoaded;

    // Display the error to the user unless this is due to a cancel
    if (error.code == -999)
        return;
    [[[UIAlertView alloc] initWithTitle:@"Web Error" message:[error localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
}


- (IBAction)previousPressed:(id)sender {
    if (_webView.canGoBack)
        [_webView goBack];
    _backButton.enabled = _webView.canGoBack;
    _forwardButton.enabled = _webView.canGoForward;
}

- (IBAction)forwardPressed:(id)sender {
    if (_webView.canGoForward)
        [_webView goForward];
    _backButton.enabled = _webView.canGoBack;
    _forwardButton.enabled = _webView.canGoForward;
}

- (IBAction)reloadPressed:(id)sender {
    [_webView reload];
    _backButton.enabled = _webView.canGoBack;
    _forwardButton.enabled = _webView.canGoForward;
}

- (IBAction)cancelPressed:(id)sender {
    [_webView stopLoading];
    _backButton.enabled = _webView.canGoBack;
    _forwardButton.enabled = _webView.canGoForward;
}
@end