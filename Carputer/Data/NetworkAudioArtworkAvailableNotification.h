#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@interface NetworkAudioArtworkAvailableNotification : NSObject

@property (strong) NSString * artist;
@property (strong) NSString * album;
@property (strong) UIImage * image;

@end