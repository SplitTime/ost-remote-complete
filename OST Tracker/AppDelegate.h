//
//  AppDelegate.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MFSideMenu.h"

//mariano.losangeles@gmail.com
//json9999

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) UINavigationController *navigationController;
@property (strong, nonatomic) MFSideMenuContainerViewController * rightMenuVC;
+ (AppDelegate *)getInstance;
- (OSTNetworkManager*) getNetworkManager;
- (void) logout;
- (void) loadLeftMenu;
- (void) showTracker;
- (void) showReview;
- (void) resetNetworkManager;

@end

