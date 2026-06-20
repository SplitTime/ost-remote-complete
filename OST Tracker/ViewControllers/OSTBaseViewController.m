//
//  OSTBaseViewController.m
//  OST Tracker
//
//  Created by Mariano Donati on 22/04/2019.
//  Copyright © 2019 OST. All rights reserved.
//

#import "OSTBaseViewController.h"
#import "UIView+Additions.h"
#import "EntryModel.h"
#import "CurrentCourse.h"
// Runner tracker is now Swift; the DidRegisterBib notification name lives in OSTConstants.
#import "OSTConstants.h"
#import "UILabel+Extension.h"
// MagicalRecord-compatibility shim (mr_*/MR_* selectors) is implemented in Swift.
#if __has_include("OST_Remote-Swift.h")
#import "OST_Remote-Swift.h"
#elif __has_include("OST_Remote_Dev-Swift.h")
#import "OST_Remote_Dev-Swift.h"
#endif

@interface OSTBaseViewController ()

@end

@implementation OSTBaseViewController

@synthesize shouldShowBadge;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OSTRunnerTrackerViewControllerDidRegisterBibNotification object:nil];
    [[AutoSyncController shared] removeObserver:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[AutoSyncController shared] addObserver:self];
    self.badgeLabel.layer.cornerRadius = self.badgeLabel.width/2;
    self.badgeLabel.clipsToBounds = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRunnerTrackerDidRegisterBib) name:OSTRunnerTrackerViewControllerDidRegisterBibNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateSyncBadge];
}

#pragma mark - AutoSyncObserver

- (void)syncManagerDidStartSynchronization:(AutoSyncController *)manager
{
    [self updateSyncBadge];
}

- (void)syncManager:(AutoSyncController *)manager progress:(CGFloat)progress
{

}

- (void)syncManagerDidFinishSynchronization:(AutoSyncController *)manager
{
    [self updateSyncBadge];
}

- (void)syncManager:(AutoSyncController *)manager didFinishSynchronizationWithErrors:(NSArray<NSError *> *)errors alternateServer:(BOOL)alternateServer
{
    [self updateSyncBadge];
}

- (void)onRunnerTrackerDidRegisterBib
{
    [self updateSyncBadge];
}

- (void)ostPositionBadgeAtMenu
{
    if (!self.menuButton || !self.badgeLabel) return;
    UIView *menuSuper = self.menuButton.superview;
    UIView *badgeSuper = self.badgeLabel.superview;
    if (!menuSuper || !badgeSuper) return;
    // The hamburger (≡) sits at the right end of the wide menu button. Anchor the
    // badge's top-right corner ~2pt inside the menu button's top-right, matching the
    // Live Entry screen exactly (menu button is a standard 122x44 on every screen).
    CGRect mf = self.menuButton.frame;
    CGPoint topRight = [menuSuper convertPoint:CGPointMake(CGRectGetMaxX(mf), CGRectGetMinY(mf)) toView:badgeSuper];
    CGRect bf = self.badgeLabel.frame;
    bf.origin.x = topRight.x - 2.0 - bf.size.width;
    bf.origin.y = topRight.y + 2.0;
    self.badgeLabel.frame = bf;
}

- (void)updateSyncBadge
{
    NSInteger entriesCount = 0;
    NSArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@ && submitted == NIL",[CurrentCourse getCurrentCourse].eventId]];
    
    NSMutableSet * set = [NSMutableSet new];
    for (EntryModel * entry in entries)
    {
        [set addObject:entry.splitName];
    }
    NSArray *splitTitles = set.allObjects;
    
    for (NSString * title in splitTitles)
    {
        NSArray *splitEntries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@ && splitName == %@ && submitted == NIL",[CurrentCourse getCurrentCourse].eventId,title]];
        entriesCount += splitEntries.count;
    }
    
    CGFloat badgeRightEdge = self.badgeLabel.right;
    if (entriesCount == 0)
    {
        self.badgeLabel.hidden = YES;
        shouldShowBadge = NO;
    }
    else
    {
        NSString *badge = [NSString stringWithFormat:@"%@",@(entriesCount)];
        shouldShowBadge = YES;
        self.badge = badge;
        self.badgeLabel.hidden = NO;
        self.badgeLabel.text = badge;
        [self.badgeLabel updateBadgeShape];
    }
    self.badgeLabel.right = badgeRightEdge;
}

- (void)updateSyncBadge_old
{
    NSMutableArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@ && submitted == NIL && bibNumber != %@",[CurrentCourse getCurrentCourse].eventId,@"-1"]].mutableCopy;
    CGFloat badgeRightEdge = self.badgeLabel.right;
    if (entries.count == 0)
    {
        self.badgeLabel.hidden = YES;
        shouldShowBadge = NO;
    }
    else
    {
        NSString *badge = [NSString stringWithFormat:@"%@",@(entries.count)];
        shouldShowBadge = YES;
        self.badge = badge;
        self.badgeLabel.hidden = NO;
        self.badgeLabel.text = badge;
        [self.badgeLabel updateBadgeShape];
    }
    self.badgeLabel.right = badgeRightEdge;
}

@end
