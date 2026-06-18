//
//  UIViewController+OSTSafeArea.m
//  OST Tracker
//

#import "UIViewController+OSTSafeArea.h"
#import <objc/runtime.h>

static const char kOSTSafeAreaAppliedKey;

@implementation UIViewController (OSTSafeArea)

- (CGFloat)ostExtraTopInset
{
    CGFloat inset = self.view.safeAreaInsets.top - 20.0; // old design assumed a 20pt status bar
    return inset > 0.5 ? inset : 0.0;
}

- (BOOL)ostShiftContentBelowSafeAreaExcludingBottom:(NSArray<UIView *> *)bottomPinned
{
    if ([objc_getAssociatedObject(self, &kOSTSafeAreaAppliedKey) boolValue]) return NO;
    CGFloat extra = [self ostExtraTopInset];
    if (extra <= 0) return NO;
    objc_setAssociatedObject(self, &kOSTSafeAreaAppliedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    for (UIView *sub in self.view.subviews)
    {
        if ([bottomPinned containsObject:sub]) continue;
        if ([sub isKindOfClass:[UIImageView class]] && CGRectEqualToRect(sub.frame, self.view.bounds)) continue; // full-screen background
        CGRect f = sub.frame;
        f.origin.y += extra;
        sub.frame = f;
    }
    return YES;
}

@end
