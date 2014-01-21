#import <Foundation/Foundation.h>
@class ClientController;

@protocol ClientControllerDelegate <NSObject>

- (void)clientController:(ClientController *)controller totalClients:(int)totalClient connectedClients:(int)connectedClients;
@end