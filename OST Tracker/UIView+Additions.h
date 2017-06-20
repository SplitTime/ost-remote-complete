//
//  UIView+Additions.m
//
//  Created by Luciano Castro
//  Copyright (c) 2016 All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (Additions)

@property (nonatomic) CGFloat left;
@property (nonatomic) CGFloat top;
@property (nonatomic) CGFloat right;
@property (nonatomic) CGFloat bottom;
@property (nonatomic) CGFloat width;
@property (nonatomic) CGFloat height;

@property (nonatomic) CGPoint origin;
@property (nonatomic) CGSize size;

+ (id)instanceFromNib;
+ (id)instanceFromNibWithName:(NSString *)nibName;

- (UIView *)findFirstResponder;

- (UIView *)findTopMostViewForPoint:(CGPoint)point;
- (UIWindow *)topmostWindow;

@end
