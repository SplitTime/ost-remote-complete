//
//  UIViewController+OSTSafeArea.h
//  OST Tracker
//
//  Shared helper for the legacy fixed-frame XIBs, which positioned content for a
//  20pt status bar and therefore bleed under the Dynamic Island on modern devices.
//

#import <UIKit/UIKit.h>

@interface UIViewController (OSTSafeArea)

/// Extra top inset to shift legacy content down by: `safeAreaInsets.top - 20`,
/// clamped to 0 on legacy devices (iPad mini 2/3 etc., where it's a no-op).
- (CGFloat)ostExtraTopInset;

/// One-time shift of the view's content below the safe area. Shifts every direct
/// subview down by `ostExtraTopInset`, EXCEPT a full-screen background image and
/// any view in `bottomPinned` (e.g. a bottom action bar that must stay put).
/// Call from `viewDidLayoutSubviews`; it no-ops after the first application and on
/// legacy devices. Returns YES if it applied.
- (BOOL)ostShiftContentBelowSafeAreaExcludingBottom:(NSArray<UIView *> *)bottomPinned;

/// One-time fix for screens with a top header/toolbar bar (the common bleed): GROWS
/// the bar downward by `ostExtraTopInset` so its background fills behind the status
/// bar/island, and shifts its child content down so it sits below the island.
/// Leaves everything else (lists, grids, bottom bars) untouched — so no gaps and
/// nothing is pushed off-screen. Pass the bar view (auto-detected if nil).
/// Call from `viewDidLayoutSubviews`. Returns YES if it applied.
- (BOOL)ostGrowTopBarBelowSafeArea:(UIView *)topBar;

@end
