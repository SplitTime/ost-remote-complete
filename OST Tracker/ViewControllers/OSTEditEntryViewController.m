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
#import "APNumberPad.h"
#import "CurrentCourse.h"
#import "OSTSound.h"

@interface OSTEditEntryViewController () <APNumberPadDelegate>

@property (strong, nonatomic) EntryModel * entry;
@property (weak, nonatomic) IBOutlet UITextField *txtTime;
@property (weak, nonatomic) IBOutlet UIButton *btnDelete;
@property (weak, nonatomic) IBOutlet UIButton *btnUpdate;
@property (strong, nonatomic) CustomUIDatePicker * customPicker;
@property (weak, nonatomic) IBOutlet UIButton *btnRightMenu;
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
    
    if (IS_IPHONE_X || IS_IPHONE_XR)
    {
        self.lblTitle.numberOfLines = 1;
        self.lblTitle.bottom = self.lblTitle.bottom + 7;
        self.btnRightMenu.bottom = self.btnRightMenu.bottom + 7;
    }
    
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
    
    [self.txtTime removeInputAssistant];
    [self.txtBibNumber removeInputAssistant];
    [self.txtDate removeInputAssistant];
    
    if (self.creatingNew)
    {
        self.btnDelete.hidden = YES;
        self.btnUpdate.left = 0;
        self.btnUpdate.width = self.view.width;
        self.btnUpdate.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [self.btnUpdate setTitle:@"Create new entry" forState:UIControlStateNormal];
    }
    
    __weak OSTEditEntryViewController * weakSelf = self;
    self.txtBibNumber.inputView = ({
        APNumberPad *numberPad = [APNumberPad numberPadWithDelegate:weakSelf];
        // configure function button
        //
        [numberPad.leftFunctionButton setTitle:@"*" forState:UIControlStateNormal];
        numberPad.leftFunctionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
        numberPad;
    });
    
    self.pacerAndAidView.height = 70;
    
    if (![CurrentCourse getCurrentCourse].monitorPacers.boolValue)
    {
        self.lblWithPacer.hidden = YES;
        self.swchPacer.hidden = YES;
    }
    else
    {
        self.lblWithPacer.hidden = NO;
        self.swchPacer.hidden = NO;
    }
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    CGFloat viewCenter = self.view.width * 0.5;
    CGFloat switchSeparation = 80;
    
    if (self.swchPacer.hidden)
    {
        self.swchStoppedHere.centerX = viewCenter;
    }
    else
    {
        self.swchStoppedHere.centerX = viewCenter - switchSeparation;
        self.swchPacer.centerX = viewCenter + switchSeparation;
    }
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
    if (self.creatingNew)
    {
        EntryModel * newEntry = [EntryModel MR_createEntity];
        
        if (self.txtBibNumber.text.length == 0)
        {
            newEntry.bibNumber = @"-1";
        }
        else newEntry.bibNumber = self.txtBibNumber.text;
        newEntry.bitKey = self.entry.bitKey;

        newEntry.splitId = self.entry.splitId;
        
        newEntry.courseName = self.entry.courseName;
        newEntry.splitName = self.entry.splitName;
        newEntry.entryCourseId = self.entry.entryCourseId;
        newEntry.combinedCourseId = self.entry.combinedCourseId;
        newEntry.splitId = self.entry.splitId;
        
        [self onDoneSelectedTime:nil];
        
        if (self.txtBibNumber.text.length)
            newEntry.bibNumber = self.txtBibNumber.text;
        
        if (self.effort)
        {
            newEntry.fullName = self.effort.fullName;
        }
        else
        {
            newEntry.fullName = nil;
        }
        
        newEntry.entryTime = [self.txtDate.date dateByAddingTimeInterval:self.customPicker.getPickerTimeInMS/1000];
        
        newEntry.displayTime = self.txtTime.text;
        NSString * dayString;
        
        NSDateFormatter * dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd"];
        dayString = [dateFormatter stringFromDate:self.txtDate.date];
        
        int timezoneoffset = (int)([[NSTimeZone systemTimeZone] secondsFromGMT])/60/60;
        if (timezoneoffset < 0)
            newEntry.absoluteTime = [NSString stringWithFormat:@"%@ %@%02d:00",dayString, self.txtTime.text,timezoneoffset];
        else newEntry.absoluteTime = [NSString stringWithFormat:@"%@ %@+%02d:00",dayString, self.txtTime.text,timezoneoffset];
        
        newEntry.source = self.entry.source;
        
        if (self.swchPacer.selected)
            newEntry.withPacer = @"true";
        else newEntry.withPacer = @"false";
        if (self.swchStoppedHere.selected)
            newEntry.stoppedHere = @"true";
        else newEntry.stoppedHere = @"false";
        
        if (self.entryHasBeenUpdatedBlock)
        {
            self.entryHasBeenUpdatedBlock(self.effort);
        }
        
        [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
        [self dismissViewControllerAnimated:YES completion:nil];
        
        return;
    }
    
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
    if (timezoneoffset < 0)
        self.entry.absoluteTime = [NSString stringWithFormat:@"%@ %@%02d:00",dayString, self.txtTime.text,timezoneoffset];
    else self.entry.absoluteTime = [NSString stringWithFormat:@"%@ %@+%02d:00",dayString, self.txtTime.text,timezoneoffset];
    
    if (self.swchPacer.selected)
        self.entry.withPacer = @"true";
    else self.entry.withPacer = @"false";
    if (self.swchStoppedHere.selected)
        self.entry.stoppedHere = @"true";
    else self.entry.stoppedHere = @"false";
    
    [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
    [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
    [self dismissViewControllerAnimated:YES completion:nil];
    
    if (self.entryHasBeenUpdatedBlock)
    {
        self.entryHasBeenUpdatedBlock(self.effort);
    }
}

- (IBAction)onClose:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onDelete:(id)sender
{
    __weak OSTEditEntryViewController * weakSelf = self;
    [OHAlertView showAlertWithTitle:@"This action cannot be undone." message:@"Are you sure you want to delete this Entry?" cancelButton:@"Cancel" otherButtons:@[@"Delete"] buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex) {
        
        if (buttonIndex == 1)
        {
            [weakSelf.entry MR_deleteEntity];
            [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
            [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
            if (weakSelf.entryHasBeenDeletedBlock)
            {
                weakSelf.entryHasBeenDeletedBlock();
            }
        }
    }];
}
- (IBAction)timeEndEditing:(id)sender
{
    self.txtTime.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)self.customPicker.hours,(long)self.customPicker.mins,self.customPicker.secs];
}

- (IBAction)onEditTime:(id)sender
{
    [self.txtTime becomeFirstResponder];
}

- (IBAction)onSwitch:(UIButton *)sender
{
    sender.selected = !sender.selected;
    [[OSTSound shared] play:@"ost-remote-switch-1"];
}

- (void) configureWithEntry:(EntryModel*)entry
{
    self.entry = entry;
    
    if (![entry.bibNumber isEqualToString:@"-1"]) {
        self.txtBibNumber.text = entry.bibNumber;
        self.txtBibNumber.selectedTextRange = [self.txtBibNumber textRangeFromPosition:self.txtBibNumber.endOfDocument toPosition:self.txtBibNumber.endOfDocument];
    }
    self.lblTitle.text = entry.courseName;
    self.swchPacer.selected = entry.withPacer.boolValue;
    self.swchStoppedHere.selected = entry.stoppedHere.boolValue;
    
    self.txtDate.date = entry.entryTime;
    
    NSDateComponents *components = [[NSCalendar currentCalendar] components: NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:entry.entryTime];
    
    self.customPicker.hours = components.hour;
    self.customPicker.mins = components.minute;
    self.customPicker.secs = components.second;
    
    [self.customPicker selectRowsInPicker];
    self.txtTime.text = [NSString stringWithFormat:@"%02ld:%02ld:%02ld",(long)components.hour,components.minute,components.second];
    
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
        
        //if (![effort checkIfEffortShouldBeInSplit:[CurrentCourse getCurrentCourse].splitName])
        //    effort = nil;
        
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

#pragma mark - APNumberPadDelegate

- (void)numberPad:(APNumberPad *)numberPad functionButtonAction:(UIButton *)functionButton textInput:(UIResponder<UITextInput> *)textInput {
    [textInput insertText:@"*"];
}


@end
