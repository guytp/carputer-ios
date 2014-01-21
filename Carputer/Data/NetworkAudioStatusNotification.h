#import <Foundation/Foundation.h>

@interface NetworkAudioStatusNotification : NSObject

@property (assign, nonatomic) int playlistPosition;
@property (strong, nonatomic) NSArray* playlist;
@property (assign, nonatomic) BOOL isPaused;
@property (assign, nonatomic) BOOL isPlaying;
@property (assign, nonatomic) BOOL isShuffle;
@property (assign, nonatomic) BOOL isRepeatAll;
@property (assign, nonatomic) BOOL canMoveNext;
@property (assign, nonatomic) BOOL canMovePrevious;
@property (assign, nonatomic) int position;
@property (assign, nonatomic) int duration;
@property (assign, nonatomic) NSString * deviceIdentifier;

@end