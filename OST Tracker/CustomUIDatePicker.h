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

- (void) selectRowsInPicker;
-(NSInteger) getPickerTimeInMS;
-(void) initialize;

@end
