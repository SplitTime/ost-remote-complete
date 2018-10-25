//
//  OSTSyncManager.m
//  OST Tracker
//
//  Created by Mariano Donati on 22/10/18.
//  Copyright © 2018 OST. All rights reserved.
//

#import "OSTSyncManager.h"
#import "AppDelegate.h"
#import "EntryModel.h"
#import "OSTNetworkManager+Login.h"
#import "OSTNetworkManager+Entries.h"
#import "UIView+Toast.h"

static OSTSyncManager *shared = nil;

@implementation OSTSyncManager

+ (void)initialize
{
    shared = [OSTSyncManager new];
}

+ (instancetype)shared
{
    return shared;
}

- (id)init
{
    if (self = [super init])
    {
        self.isSyncing = NO;
        self.progress = 0;
        self.showToastOnCompletion = YES;
        self.syncingEntries = @[];
        self.delegates = [NSMutableArray new];
    }
    return self;
}

- (void)syncEntries:(NSArray *)records
{
    if (self.isSyncing) {
        return;
    }
    
    NSMutableArray * entries = [records mutableCopy];
    
    self.syncingEntries = records;
    
    [self notifySynchronizationStart];
    
    [[AppDelegate getInstance].getNetworkManager autoLoginWithCompletionBlock:^(id object) {
        [self submitEntries:entries useAlternateServer:NO completionBlock:^(id object) {
            [self notifySynchronizationDidFinish];
        } errorBlock:^(NSError *error) {
            [self notifySynchronizationDidFinishWithErrors:@[error] alternateServer:NO];
        }];
    } errorBlock:^(NSError *error1) {
        [self submitEntries:entries useAlternateServer:YES completionBlock:^(id object) {
            [self notifySynchronizationDidFinish];
        } errorBlock:^(NSError *error2) {
            [self notifySynchronizationDidFinishWithErrors:@[error1, error2] alternateServer:YES];
        }];
    }];
}

- (void)submitEntries:(NSMutableArray*) entries useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSArray * subEntries = nil;
    
    long entriesCount = entries.count;
    
    if (entriesCount > 300)
    {
        subEntries = [entries subarrayWithRange:NSMakeRange(0, 300)];
        self.progress = 300.0/entriesCount;
    }
    else
    {
        subEntries = [entries subarrayWithRange:NSMakeRange(0, entriesCount)];
        self.progress = 1;
    }
    
    [self notifySynchronizationProgress:self.progress];
    
    if (subEntries.count == 0)
    {
        onCompletion(nil);
        return;
    }
    
    [[AppDelegate getInstance].getNetworkManager submitEventGroupEntries:subEntries useAlternateServer:alternateServer completionBlock:^(id object) {
        
        for (EntryModel * entry in subEntries)
        {
            entry.submitted = @(YES);
            [entries removeObject:entry];
        }
        
        [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
        
        [self submitEntries:entries useAlternateServer:alternateServer completionBlock:onCompletion errorBlock:onError];
        
    } errorBlock:^(NSError *error) {
        onError(error);
    }];
}

- (void)notifySynchronizationStart
{
    self.isSyncing = YES;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    for (id<OSTSyncManagerDelegate> delegate in self.delegates) {
        [delegate syncManagerDidStartSynchronization:self];
    }
}

- (void)notifySynchronizationProgress:(CGFloat)progress
{
    for (id<OSTSyncManagerDelegate> delegate in self.delegates) {
        [delegate syncManager:self progress:progress];
    }
}

- (void)notifySynchronizationDidFinish
{
    self.isSyncing = NO;
    self.syncingEntries = @[];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    for (id<OSTSyncManagerDelegate> delegate in self.delegates) {
        [delegate syncManagerDidFinishSynchronization:self];
    }
    [self showToastIfAppropriateWithErrors:@[]];
}

- (void)notifySynchronizationDidFinishWithErrors:(NSArray<NSError *>*)errors alternateServer:(BOOL)alternateServer
{
    self.isSyncing = NO;
    self.syncingEntries = @[];
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    for (id<OSTSyncManagerDelegate> delegate in self.delegates)
    {
        [delegate syncManager:self didFinishSynchronizationWithErrors:errors alternateServer:alternateServer];
    }
    [self showToastIfAppropriateWithErrors:errors];
}

- (BOOL)isSyncingEntry:(EntryModel *)entry
{
    for (EntryModel *syncingEntry in self.syncingEntries)
    {
        if ([syncingEntry.entryId isEqualToNumber:entry.entryId])
        {
            return YES;
        }
    }
    return NO;
}

- (void)showToastIfAppropriateWithErrors:(NSArray<NSError *>*)errors
{
    if (self.showToastOnCompletion) {
        [CSToastManager setTapToDismissEnabled:YES];
        
        UIWindow *window = [[AppDelegate getInstance] window];
        BOOL finishedWithError = (errors != nil && errors.count > 0);
        
        CSToastStyle *style = [[CSToastStyle alloc] initWithDefaultStyle];
        style.messageColor = [UIColor blackColor];
        style.backgroundColor = (finishedWithError) ? [UIColor colorWithRed:247/255.f green:45/255.f blue:0 alpha:1] : [UIColor colorWithRed:88/255.f green:182/255.f blue:73/255.f alpha:1];
        
        NSString *successfulMessage = @"Times synced successfully.";
        NSString *errorMessage = @"Failed to sync times.";
        
        NSString *message = (finishedWithError) ? errorMessage : successfulMessage;
        
        // present the toast with the new style
        [window makeToast:message duration:3.0 position:CSToastPositionTop style:style];
    }
}

@end
