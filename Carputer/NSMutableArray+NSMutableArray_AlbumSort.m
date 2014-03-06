#import "NSMutableArray+NSMutableArray_AlbumSort.h"
#import "NetworkAudioFile.h"

@implementation NSMutableArray (NSMutableArray_AlbumSort)

- (NSComparisonResult)albumSort:(NSMutableArray *)otherObject {
    NetworkAudioFile * trackOneSelf = [(NSMutableArray *)self objectAtIndex:0];
    NetworkAudioFile * trackOneOther = [otherObject objectAtIndex:0];
    return [[trackOneSelf.album lowercaseString] compare:[trackOneOther.album lowercaseString]];
}

@end