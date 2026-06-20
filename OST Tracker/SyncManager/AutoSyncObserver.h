//
//  AutoSyncObserver.h
//  OST Tracker
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@class AutoSyncController;

/// Replaces OSTSyncManagerDelegate. Same callback shape so the Review pane,
/// the badge base class, and the right menu keep their existing logic.
@protocol AutoSyncObserver <NSObject>
- (void)syncManagerDidStartSynchronization:(AutoSyncController *)manager;
- (void)syncManager:(AutoSyncController *)manager progress:(CGFloat)progress;
- (void)syncManagerDidFinishSynchronization:(AutoSyncController *)manager;
- (void)syncManager:(AutoSyncController *)manager didFinishSynchronizationWithErrors:(NSArray<NSError *> *)errors alternateServer:(BOOL)alternateServer;
@end

NS_ASSUME_NONNULL_END
