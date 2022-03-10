//
//  AppDelegate.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "AppDelegate.h"
#import "OSTLoginViewController.h"
#import "MFSideMenu.h"
#import "OSTRunnerTrackerViewController.h"
#import "OSTRightMenuViewController.h"
#import "OSTReviewSubmitViewController.h"
#import "CurrentCourse.h"
#import "IQKeyboardManager.h"
#import "CourseSplits.h"
#import "EffortModel.h"
#import "UIView+Additions.h"
#import "OSTUtilitiesViewController.h"
#import "OSTAboutViewController.h"

@interface AppDelegate ()

@property (strong, nonatomic) OSTNetworkManager* networkManager;
@property (strong, nonatomic) OSTRunnerTrackerViewController * OSTTrackerVC;

@end

@implementation AppDelegate

+ (AppDelegate *)getInstance
{
    return (AppDelegate*)[[UIApplication sharedApplication] delegate];
}

- (void) resetNetworkManager
{
    self.networkManager = [[OSTNetworkManager alloc] init];
}

- (OSTNetworkManager*) getNetworkManager
{
    if (self.networkManager == nil)
    {
        self.networkManager = [[OSTNetworkManager alloc] init];
        [self.networkManager.reachabilityManager startMonitoring];
    }
    return self.networkManager;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    [self initializeCoredata];
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
    [IQKeyboardManager sharedManager].keyboardDistanceFromTextField = 80;
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    if ([CurrentCourse getCurrentCourse])
    {
        [self loadLeftMenu];
    }
    else
    {
        [self loadLogin];
    }
    
    [self.window makeKeyAndVisible];
    
    [UIApplication sharedApplication].applicationSupportsShakeToEdit = NO;

    return YES;
}

- (void) loadLogin
{
    OSTLoginViewController * loginVC = [[OSTLoginViewController alloc] initWithNibName:nil bundle:nil];
    
    self.window.rootViewController = loginVC;
}

- (void) loadLeftMenu
{
    if (!self.rightMenuVC)
    {
        self.rightMenuVC = [[MFSideMenuContainerViewController alloc] init];
        self.rightMenuVC.rightMenuViewController = [[OSTRightMenuViewController alloc] initWithNibName:nil bundle:nil];
        self.rightMenuVC.rightMenuViewController.view.height = self.window.height;
    }

    if (!self.OSTTrackerVC)
    {
        self.OSTTrackerVC = [[OSTRunnerTrackerViewController alloc] initWithNibName:nil bundle:nil];
    }
    else
    {
        [self.OSTTrackerVC cleanData];
    }

    self.rightMenuVC.centerViewController = self.OSTTrackerVC;
    [[self.rightMenuVC.centerViewController view] setFrame:self.window.frame];
    self.window.rootViewController = self.rightMenuVC;
}

- (void) showTracker
{
    self.rightMenuVC.centerViewController= self.OSTTrackerVC;
    [[self.rightMenuVC.centerViewController view] setFrame:self.window.frame];
    [self.OSTTrackerVC cleanData];
}

- (void) showReview
{
    self.rightMenuVC.centerViewController = [[OSTReviewSubmitViewController alloc] initWithNibName:nil bundle:nil];
    [[self.rightMenuVC.centerViewController view] setFrame:self.window.frame];
}

- (void) showUtilities
{
    self.rightMenuVC.centerViewController = [[OSTUtilitiesViewController alloc] initWithNibName:nil bundle:nil];
    [[self.rightMenuVC.centerViewController view] setFrame:self.window.frame];
}
- (void) showAbout
{
    self.rightMenuVC.centerViewController = [[OSTAboutViewController alloc] initWithNibName:nil bundle:nil];
    [[self.rightMenuVC.centerViewController view] setFrame:self.window.frame];
}
- (void) logout
{
    [CurrentCourse MR_truncateAll];
    [CourseSplits MR_truncateAll];
    [EffortModel MR_truncateAll];
    [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
    [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
    [[AppDelegate getInstance].getNetworkManager addTokenToHeader:nil];
    
    OSTLoginViewController * loginVC = [[OSTLoginViewController alloc] initWithNibName:nil bundle:nil];
    self.window.rootViewController = loginVC;
}

#pragma mark - CoreData Setup

- (void) initializeCoredata
{
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:OSTCoredataFile];
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
