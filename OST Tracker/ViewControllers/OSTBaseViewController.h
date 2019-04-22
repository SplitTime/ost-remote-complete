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

- (void)updateSyncBadge;

@end

NS_ASSUME_NONNULL_END
