//
//  OSTSyncManager.h
//  OST Tracker
//
//  Created by Mariano Donati on 22/10/18.
//  Copyright © 2018 OST. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class OSTSyncManager;
@class EntryModel;

@protocol OSTSyncManagerDelegate

- (void)syncManagerDidStartSynchronization:(OSTSyncManager *)manager;
- (void)syncManager:(OSTSyncManager *)manager progress:(CGFloat)progress;
- (void)syncManagerDidFinishSynchronization:(OSTSyncManager *)manager;
- (void)syncManager:(OSTSyncManager *)manager didFinishSynchronizationWithErrors:(NSArray<NSError *>*)errors alternateServer:(BOOL)alternateServer;

@end

@interface OSTSyncManager : NSObject

@property (nonatomic,strong) NSMutableArray<id<OSTSyncManagerDelegate>>* delegates;
@property (nonatomic,assign) CGFloat progress;
@property (nonatomic,assign) BOOL isSyncing;
@property (nonatomic,assign) BOOL showToastOnCompletion;
@property (nonatomic,strong) NSArray *syncingEntries;

+ (instancetype)shared;
- (void)syncEntries:(NSArray *)records;
- (BOOL)isSyncingEntry:(EntryModel *)entry;

@end

NS_ASSUME_NONNULL_END
