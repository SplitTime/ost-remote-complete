//
//  OSTEditEntryViewController.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/15/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTEditEntryViewController.h"
#import "EffortModel.h"
#import "IQKeyboardManager.h"
#import "CustomUIDatePicker.h"
#import "UIView+Additions.h"

@interface OSTEditEntryViewController ()

@property (strong, nonatomic) EntryModel * entry;
@property (weak, nonatomic) IBOutlet UITextField *txtTime;
@property (strong, nonatomic) CustomUIDatePicker * customPicker;
@property (strong, nonatomic) EffortModel * effort;

@end

@implementation OSTEditEntryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.txtDate.dropDownMode = IQDropDownModeDatePicker;
    [IQKeyboardManager sharedManager].enableAutoToolbar = YES;
    
    self.customPicker = [[CustomUIDatePicker alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 200)];

    self.txtTime.inputView = self.customPicker;
    
    UIToolbar* keyboardToolbar = [[UIToolbar alloc] init];
    [keyboardToolbar sizeToFit];
    UIBarButtonItem *flexBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];
    UIBarButtonItem *doneBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                      target:self action:@selector(onDoneSelectedTime:)];
    UIBarButtonItem *cancelBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                      target:self action:@selector(onDoneSelectedTime:)];
    keyboardToolbar.items = @[cancelBarButton, flexBarButton, doneBarButton];
    
    self.txtTime.inputAccessoryView = keyboardToolbar;
    [IQKeyboardManager sharedManager].enable = YES;
}

- (void) onDoneSelectedTime:(id) sender
{
    [self.txtTime resignFirstResponder];
}

- (void) onCancelTime:(id) sender
{
    [self.txtTime resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onBibNumber:(id)sender
{
    [self.txtBibNumber becomeFirstResponder];
}

- (IBAction)onTime:(id)sender
{
    [self.txtDate becomeFirstResponder];
}

- (IBAction)onUpdate:(id)sender
{
    [self onDoneSelectedTime:nil];
    if (self.txtBibNumber.text.length)
        self.entry.bibNumber = self.txtBibNumber.text;
    
    if (self.effort)
    {
        self.entry.fullName = self.effort.fullName;
    }
    else
    {
        self.entry.fullName = nil;
    }
    
    self.entry.entryTime = [self.txtDate.date dateByAddingTimeInterval:self.customPicker.getPickerTimeInMS/1000];
    
    self.entry.displayTime = self.txtTime.text;
    NSString * dayString;
    
    NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    dayString = [dateFormatter stringFromDate:self.txtDate.date];
    
    int timezoneoffset = (int)([[NSTimeZone systemTimeZone] secondsFromGMT])/60/60;
    self.entry.absoluteTime = [NSString stringWithFormat:@"%@ %@%02d:00",dayString, self.txtTime.text,timezoneoffset];
    
    if (self.swchPacer.on)
        self.entry.withPacer = @"true";
    else self.entry.withPacer = @"false";
    if (self.swchStoppedHere.on)
        self.entry.stoppedHere = @"true";
    else self.entry.stoppedHere = @"false";
    
    [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
    [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if (self.entryHasBeenUpdatedBlock)
    {
        self.entryHasBeenUpdatedBlock();
    }
}

- (IBAction)onClose:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onDelete:(id)sender
{
    [OHAlertView showAlertWithTitle:@"This action cannot be undone." message:@"Are you sure you want to delete this Entry?" cancelButton:@"Cancel" otherButtons:@[@"Delete"] buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex) {
        
        if (buttonIndex == 1)
        {
            [self.entry MR_deleteEntity];
            [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
            [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
            [self dismissViewControllerAnimated:YES completion:nil];
            if (self.entryHasBeenDeletedBlock)
            {
                self.entryHasBeenDeletedBlock();
            }
        }
    }];
}
- (IBAction)timeEndEditing:(id)sender
{
    self.txtTime.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",self.customPicker.hours,self.customPicker.mins,self.customPicker.secs];
}

- (IBAction)onEditTime:(id)sender
{
    [self.txtTime becomeFirstResponder];
}

- (void) configureWithEntry:(EntryModel*)entry
{
    self.entry = entry;
    
    if (![entry.bibNumber isEqualToString:@"-1"])
        self.txtBibNumber.text = entry.bibNumber;
    self.lblTitle.text = entry.courseName;
    self.swchPacer.on = entry.withPacer.boolValue;
    self.swchStoppedHere.on = entry.stoppedHere.boolValue;
    
    self.txtDate.date = entry.entryTime;
    
    NSDateComponents *components = [[NSCalendar currentCalendar] components: NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:entry.entryTime];
    
    self.customPicker.hours = components.hour;
    self.customPicker.mins = components.minute;
    self.customPicker.secs = components.second;
    
    [self.customPicker selectRowsInPicker];
    self.txtTime.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",components.hour,components.minute,components.second];
    
    [self onBibNumberChanged:nil];
}

- (IBAction)onBibNumberChanged:(id)sender
{
    self.lblRunner.textColor = [UIColor darkGrayColor];
    if (self.txtBibNumber.text.length == 0)
    {
        self.lblRunner.text = @"";
    }
    else
    {
        EffortModel * effort = [EffortModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber == %@", [NSDecimalNumber decimalNumberWithString:self.txtBibNumber.text]]];
        
        if (effort)
        {
            self.lblRunner.text = [NSString stringWithFormat:@"Bib Found: %@",effort.fullName];
            self.effort = effort;
        }
        else
        {
            self.lblRunner.text = @"Bib Not Found!";
            self.lblRunner.textColor = [UIColor redColor];
            self.effort = nil;
        }
    }
}

- (void)dealloc
{
    [IQKeyboardManager sharedManager].enable = NO;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
}

@end
