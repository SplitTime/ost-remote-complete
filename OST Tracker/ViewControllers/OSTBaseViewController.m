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

@interface OSTBaseViewController ()

@end

@implementation OSTBaseViewController

- (void)dealloc
{
    [[[OSTSyncManager shared] delegates] removeObject:self];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [[[OSTSyncManager shared] delegates] addObject:self];
    self.badgeLabel.layer.cornerRadius = self.badgeLabel.width/2;
    self.badgeLabel.clipsToBounds = YES;
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

- (void)updateSyncBadge
{
    NSMutableArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@ && submitted == NIL && bibNumber != %@",[CurrentCourse getCurrentCourse].eventId,@"-1"]].mutableCopy;
    if (entries.count == 0)
    {
        self.badgeLabel.hidden = YES;
    }
    else
    {
        self.badgeLabel.hidden = NO;
        self.badgeLabel.text = [NSString stringWithFormat:@"%@",@(entries.count)];
    }
}

@end
