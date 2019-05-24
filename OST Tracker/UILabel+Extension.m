//
//  UILabel+UILabel_Extension.m
//  OST Tracker
//
//  Created by Mariano Donati on 24/05/2019.
//  Copyright © 2019 OST. All rights reserved.
//

#import "UILabel+Extension.h"
#import "UIView+Additions.h"

@implementation UILabel (Extension)

- (void)updateBadgeShape
{
    if (self.text.length == 1)
    {
        self.width = self.height;
    }
    else
    {
        CGRect badgeSize = [self.text boundingRectWithSize:CGSizeMake(FLT_MAX, self.height) options:0 attributes:@{NSFontAttributeName:self.font} context:nil];
        CGFloat padding = 8;
        self.width = badgeSize.size.width + padding * 2;
    }
}

@end
