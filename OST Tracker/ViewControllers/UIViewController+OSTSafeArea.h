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

/// One-time automatic safe-area fix for the legacy fixed-frame XIB screens. Call
/// from `viewDidLayoutSubviews`; no-ops after the first application and on legacy
/// devices. By geometry it:
///   - grows the top bar to fill behind the status bar/island and moves its content down,
///   - shifts mid-screen content down by `ostExtraTopInset` (so it clears the island),
///   - lifts full-width bottom bars up by the bottom safe-area inset (home indicator),
///   - leaves full-screen background images put.
/// Returns YES if it applied.
- (BOOL)ostApplySafeAreaFix;

@end
