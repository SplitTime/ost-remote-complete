//
//  OSTCheckmarkView.h
//  OST Tracker
//
//  Created by Mariano Donati on 20/11/18.
//  Copyright © 2018 OST. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

IB_DESIGNABLE
@interface OSTCheckmarkView : UIControl

@property (nonatomic) IBInspectable UIColor *color;
@property (nonatomic) IBInspectable NSString *text;

@end

NS_ASSUME_NONNULL_END
