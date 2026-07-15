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

- (BOOL)ostApplySafeAreaFix
{
    if ([objc_getAssociatedObject(self, &kOSTSafeAreaAppliedKey) boolValue]) return NO;
    CGFloat extra = [self ostExtraTopInset];
    if (extra <= 0) return NO;
    objc_setAssociatedObject(self, &kOSTSafeAreaAppliedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    CGFloat width = self.view.bounds.size.width;
    CGFloat height = self.view.bounds.size.height;
    CGFloat bottomInset = self.view.safeAreaInsets.bottom;

    // Find the top bar: a near-full-width direct subview anchored at y≈0 that isn't
    // the full-screen background.
    UIView *topBar = nil;
    for (UIView *sub in self.view.subviews)
    {
        CGRect f = sub.frame;
        if (CGRectEqualToRect(f, self.view.bounds)) continue;
        if (f.origin.y <= 1.0 && f.size.width >= width * 0.85 && f.size.height >= 28 && f.size.height <= 140)
        {
            topBar = sub;
            break;
        }
    }

    for (UIView *sub in self.view.subviews)
    {
        if (sub == topBar) continue;
        CGRect f = sub.frame;
        if ([sub isKindOfClass:[UIImageView class]] && CGRectEqualToRect(f, self.view.bounds)) continue; // full-screen background

        BOOL isBottomBar = (f.origin.y > height * 0.65 && f.size.width >= width * 0.85 && f.size.height <= 160);
        if (isBottomBar)
        {
            // A bottom action bar: don't push it off-screen — lift it up for the home indicator.
            if (bottomInset > 0.5) { f.origin.y -= bottomInset; sub.frame = f; }
        }
        else
        {
            f.origin.y += extra; // shift content down below the island
            sub.frame = f;
        }
    }

    // Grow the top bar to fill behind the status bar/island, and move its content
    // down by the same amount everything else moved.
    if (topBar)
    {
        CGRect b = topBar.frame;
        b.size.height += extra;
        topBar.frame = b;
        for (UIView *child in topBar.subviews)
        {
            CGRect cf = child.frame;
            cf.origin.y += extra;
            child.frame = cf;
        }
    }
    return YES;
}

@end
