//
//  AppDelegate.m
//  Carputer
//
//  Created by Guy Powell on 02/01/2014.
//  Copyright (c) 2014 Guytp. All rights reserved.
//

#import "AppDelegate.h"
#import "DebugViewController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Setup background of window and setup status bar
    self.window.backgroundColor = [UIColor blackColor];
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    
    // Start the client controller
    _clientController = [ClientController applicationInstance];
    _clientController.delegate = self;
    
    // Override point for customization after application launch.
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}



- (void)clientController:(ClientController *)controller totalClients:(int)totalClient connectedClients:(int)connectedClients {
    [self.window.rootViewController dismissViewControllerAnimated:NO completion:nil];
    UIStoryboard* storyBoard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UIViewController* detailVC = [storyBoard instantiateViewControllerWithIdentifier:connectedClients > 0 ? @"Main Tab" : @"Detecting"];
    [self.window performSelectorOnMainThread:@selector(setRootViewController:) withObject:detailVC waitUntilDone:NO];
}
@end
