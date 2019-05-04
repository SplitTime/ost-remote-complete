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
#import "OSTRunnerTrackerViewController.h"

@interface OSTBaseViewController ()

@end

@implementation OSTBaseViewController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OSTRunnerTrackerViewControllerDidRegisterBibNotification object:nil];
    [[[OSTSyncManager shared] delegates] removeObject:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[[OSTSyncManager shared] delegates] addObject:self];
    self.badgeLabel.layer.cornerRadius = self.badgeLabel.width/2;
    self.badgeLabel.clipsToBounds = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onRunnerTrackerDidRegisterBib) name:OSTRunnerTrackerViewControllerDidRegisterBibNotification object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateSyncBadge];
}

#pragma mark - OSTSyncManagerDelegate

- (void)syncManagerDidStartSynchronization:(OSTSyncManager *)manager
{
    [self updateSyncBadge];
}

- (void)syncManager:(OSTSyncManager *)manager progress:(CGFloat)progress
{
    
}

- (void)syncManagerDidFinishSynchronization:(OSTSyncManager *)manager
{
    [self updateSyncBadge];
}

- (void)syncManager:(OSTSyncManager *)manager didFinishSynchronizationWithErrors:(NSArray<NSError *> *)errors alternateServer:(BOOL)alternateServer
{
    [self updateSyncBadge];
}

- (void)onRunnerTrackerDidRegisterBib
{
    [self updateSyncBadge];
}

- (void)updateSyncBadge
{
    NSMutableArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@ && submitted == NIL && bibNumber != %@",[CurrentCourse getCurrentCourse].eventId,@"-1"]].mutableCopy;
    CGFloat badgeRightEdge = self.badgeLabel.right;
    if (entries.count == 0)
    {
        self.badgeLabel.hidden = YES;
    }
    else
    {
        NSString *badge = [NSString stringWithFormat:@"%@",@(entries.count)];
        self.badgeLabel.hidden = NO;
        self.badgeLabel.text = badge;
        
        if (badge.length == 1)
        {
            self.badgeLabel.width = self.badgeLabel.height;
        }
        else
        {
            CGRect badgeSize = [badge boundingRectWithSize:CGSizeMake(FLT_MAX, self.badgeLabel.height) options:0 attributes:@{NSFontAttributeName:self.badgeLabel.font} context:nil];
            CGFloat padding = 8;
            self.badgeLabel.width = badgeSize.size.width + padding * 2;
        }
    }
    self.badgeLabel.right = badgeRightEdge;
}

@end
