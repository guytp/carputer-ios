#import <Foundation/Foundation.h>

@interface NetworkAudioLibraryUpdateNotification : NSObject

@property (strong, nonatomic) NSArray * deletedFiles;
@property (strong, nonatomic) NSArray * onlineFiles;
@property (strong, nonatomic) NSArray * offlineFiles;
@property (strong, nonatomic) NSArray * updatedFiles;
@property (strong, nonatomic) NSArray * addedFiles;
@property (assign, nonatomic) NSString * deviceIdentifier;

@end