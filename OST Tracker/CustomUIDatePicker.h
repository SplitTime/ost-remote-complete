//
//  CustomUIDatePicker.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/23/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface CustomUIDatePicker : UIPickerView <UIPickerViewDataSource, UIPickerViewDelegate>

@property NSInteger hours;
@property NSInteger mins;
@property NSInteger secs;

/// Fired whenever the user spins a wheel (after hours/mins/secs update), so a
/// host can reflect the value live and commit in place — no Done button needed.
@property (nonatomic, copy, nullable) void (^onChange)(void);

- (void) selectRowsInPicker;
-(NSInteger) getPickerTimeInMS;
-(void) initialize;

@end
