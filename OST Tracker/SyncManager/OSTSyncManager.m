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

static OSTSyncManager *shared = nil;

@interface OSTSyncManager ()

@property (nonatomic,strong) NSArray *syncingEntries;

@end

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
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    for (id<OSTSyncManagerDelegate> delegate in self.delegates) {
        [delegate syncManagerDidFinishSynchronization:self];
    }
}

- (void)notifySynchronizationDidFinishWithErrors:(NSArray<NSError *>*)errors alternateServer:(BOOL)alternateServer
{
    self.isSyncing = NO;
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
    for (id<OSTSyncManagerDelegate> delegate in self.delegates)
    {
        [delegate syncManager:self didFinishSynchronizationWithErrors:errors alternateServer:alternateServer];
    }
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

@end
