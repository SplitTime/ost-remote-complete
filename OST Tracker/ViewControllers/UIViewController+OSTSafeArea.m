//
//  UIViewController+OSTSafeArea.m
//  OST Tracker
//

#import "UIViewController+OSTSafeArea.h"

@implementation UIViewController (OSTSafeArea)

- (CGFloat)ostExtraTopInset
{
    CGFloat inset = self.view.safeAreaInsets.top - 20.0; // old design assumed a 20pt status bar
    return inset > 0.5 ? inset : 0.0;
}

@end
