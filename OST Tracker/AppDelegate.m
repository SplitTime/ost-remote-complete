//
//  AppDelegate.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "AppDelegate.h"
// Generated Swift header — module name differs between the two app targets.
// (Provides OSTDrawerContainer + the Swift screens.)
#if __has_include("OST_Remote-Swift.h")
#import "OST_Remote-Swift.h"
#elif __has_include("OST_Remote_Dev-Swift.h")
#import "OST_Remote_Dev-Swift.h"
#endif
// OSTRunnerTrackerViewController is now Swift (visible via the generated header above).
#import "OSTRightMenuViewController.h"
// OSTReviewSubmitViewController is now Swift (visible via the generated header above).
#import "CurrentCourse.h"
#import "CourseSplits.h"
#import "EffortModel.h"
#import "UIView+Additions.h"
// OSTUtilitiesViewController and OSTAboutViewController are now Swift
// (visible via the generated OST_Remote-Swift.h imported above).

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
        [self.networkManager startMonitoring];
    }
    return self.networkManager;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    
    [self initializeCoredata];

    // Force lazy creation of the auto-sync controller so it begins observing
    // Core Data saves. Runs unconditionally (incl. the unit-test host) now that
    // there's no reachability probe; AutoSyncController itself skips any live
    // network/Core Data submit under XCTest, so launch-time creation is safe.
    (void)[AutoSyncController shared];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    CurrentCourse *savedCourse = [CurrentCourse getCurrentCourse];
    NSLog(@"[OST] launch: savedCourse eventId=%@ name=%@", savedCourse.eventId, savedCourse.eventName);
    if (savedCourse)
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
    LoginViewController * loginVC = [[LoginViewController alloc] init];
    
    self.window.rootViewController = loginVC;
}

- (void) loadLeftMenu
{
    if (!self.rightMenuVC)
    {
        self.rightMenuVC = [[OSTDrawerContainer alloc] init];
        self.rightMenuVC.rightMenuViewController = [[OSTRightMenuViewController alloc] initWithNibName:nil bundle:nil];
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
    
    LoginViewController * loginVC = [[LoginViewController alloc] init];
    self.window.rootViewController = loginVC;
}

#pragma mark - CoreData Setup

- (void) initializeCoredata
{
    // Native CoreDataStack (replaces MagicalRecord); opens the same on-disk store.
    [OSTCoreData bootstrap];
}


- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    [[AutoSyncController shared] applicationDidEnterBackground];
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    [[AutoSyncController shared] applicationDidBecomeActive];
}


- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}


@end
