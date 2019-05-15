//
//  OSTRunnerBadge.h
//  OST Tracker
//
//  Created by Mariano Donati on 10/05/2019.
//  Copyright © 2019 OST. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OSTRunnerBadgeViewModel.h"

NS_ASSUME_NONNULL_BEGIN

IB_DESIGNABLE
@interface OSTRunnerBadge : UIView

- (void)updateWithModel:(OSTRunnerBadgeViewModel *)viewModel;
- (void)adjustFontSizes;

@end

NS_ASSUME_NONNULL_END
