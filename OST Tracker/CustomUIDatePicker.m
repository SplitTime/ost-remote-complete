//
//  CustomUIDatePicker.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/23/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "CustomUIDatePicker.h"

@implementation CustomUIDatePicker

-(instancetype)init {
    self = [super init];
    [self initialize];
    return self;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    [self initialize];
    return self;
}

-(instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    [self initialize];
    return self;
}

-(void) initialize {
    self.delegate = self;
    self.dataSource = self;
    
    int height = 20;
    int offsetX = self.frame.size.width / 3;
    int offsetY = self.frame.size.height / 2 - height / 2;
    int marginX = 45;
    int width = offsetX - marginX;
    
    UILabel *hourLabel = [[UILabel alloc] initWithFrame:CGRectMake(marginX, offsetY, width, height)];
    hourLabel.text = @"hour";
    [self addSubview:hourLabel];
    hourLabel.autoresizingMask = 0xff;
    
    UILabel *minsLabel = [[UILabel alloc] initWithFrame:CGRectMake(marginX + offsetX, offsetY, width, height)];
    minsLabel.text = @"min";
    minsLabel.autoresizingMask = 0xff;
    [self addSubview:minsLabel];
    
    UILabel *secsLabel = [[UILabel alloc] initWithFrame:CGRectMake(marginX + offsetX * 2, offsetY, width, height)];
    secsLabel.text = @"sec";
    secsLabel.autoresizingMask = 0xff;
    [self addSubview:secsLabel];
}

-(void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    if (component == 0) {
        self.hours = row;
    } else if (component == 1) {
        self.mins = row;
    } else if (component == 2) {
        self.secs = row;
    }
}

- (void) selectRowsInPicker
{
    [self selectRow:self.hours inComponent:0 animated:YES];
    [self selectRow:self.mins inComponent:1 animated:YES];
    [self selectRow:self.secs inComponent:2 animated:YES];
}

-(NSInteger)getPickerTimeInMS {
    return (self.hours * 60 * 60 + self.mins * 60 + self.secs) * 1000;
}

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 3;
}
-(NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if(component == 0)
        return 24;
    
    return 60;
}

- (CGFloat)pickerView:(UIPickerView *)pickerView rowHeightForComponent:(NSInteger)component
{
    return 30;
}

-(UIView *)pickerView:(UIPickerView *)pickerView viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view
{
    if (view != nil) {
        ((UILabel*)view).text = [NSString stringWithFormat:@"%lu", (long)row];
        return view;
    }
    UILabel *columnView = [[UILabel alloc] initWithFrame:CGRectMake(35, 0, self.frame.size.width/3 - 35, 30)];
    columnView.text = [NSString stringWithFormat:@"%lu", (long)row];
    columnView.textAlignment = NSTextAlignmentLeft;
    
    return columnView;
}

@end

