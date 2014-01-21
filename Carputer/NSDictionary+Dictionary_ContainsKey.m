#import "NSDictionary+Dictionary_ContainsKey.h"

@implementation NSDictionary (Dictionary_ContainsKey)
- (BOOL)containsKey: (NSString *)key {
    return [[self allKeys] containsObject:key];
}
@end