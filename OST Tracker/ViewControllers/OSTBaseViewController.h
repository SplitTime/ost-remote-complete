//
//  OSTBaseViewController.h
//  OST Tracker
//
//  Created by Mariano Donati on 22/04/2019.
//  Copyright © 2019 OST. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OSTSyncManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface OSTBaseViewController : UIViewController<OSTSyncManagerDelegate>

@property (nonatomic,weak) IBOutlet UIButton *menuButton;
@property (nonatomic,weak) IBOutlet UILabel *badgeLabel;
@property (nonatomic,weak) NSString *badge;
@property (nonatomic,readonly) BOOL shouldShowBadge;

- (void)updateSyncBadge;

/// Positions the sync-count badge at the top-left corner of the menu (hamburger)
/// button. Call after the safe-area fix in `viewDidLayoutSubviews` so the badge
/// stays pinned to the hamburger wherever it ends up.
- (void)ostPositionBadgeAtMenu;

@end

NS_ASSUME_NONNULL_END
