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

@interface OSTEditEntryViewController ()

@property (strong, nonatomic) EntryModel * entry;

@end

@implementation OSTEditEntryViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.txtDate.dropDownMode = IQDropDownModeDateTimePicker;
    [IQKeyboardManager sharedManager].enableAutoToolbar = YES;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onUpdate:(id)sender
{
    self.entry.bibNumber = self.txtBibNumber.text;
    //self.entry.withPacer = [NSDecimalNumber decimalNumberWithDecimal:@(self.swchPacer.on)];
    //self.entry.stoppedHere = @()
    
    if (self.swchPacer.on)
        self.entry.withPacer = @"true";
    else self.entry.withPacer = @"false";
    if (self.swchStoppedHere.on)
        self.entry.stoppedHere = @"true";
    else self.entry.stoppedHere = @"false";
    
    [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
    [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onClose:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)onDelete:(id)sender
{
    [OHAlertView showAlertWithTitle:@"Warning!" message:@"Are you sure you want to delete this Entry?" cancelButton:@"Cancel" otherButtons:@[@"Delete"] buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex) {
        
        if (buttonIndex == 1)
        {
            [self.entry MR_deleteEntity];
            [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
            [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    }];
}

- (void) configureWithEntry:(EntryModel*)entry
{
    self.entry = entry;
    
    self.txtBibNumber.text = entry.bibNumber;
    self.lblTitle.text = entry.courseName;
    self.swchPacer.on = entry.withPacer.boolValue;
    self.swchStoppedHere.on = entry.stoppedHere.boolValue;
    
    //self.txtDate.selectedItem = entry.absoluteTime;
    
    [self onBibNumberChanged:nil];
}

- (IBAction)onBibNumberChanged:(id)sender
{
    self.lblRunner.textColor = [UIColor darkGrayColor];
    if (self.txtBibNumber.text.length == 0)
    {
        self.lblRunner.text = @"Add Bib Number to search for runner";
    }
    else
    {
        EffortModel * effort = [EffortModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber == %@", [NSDecimalNumber decimalNumberWithString:self.txtBibNumber.text]]];
        
        if (effort)
        {
            self.lblRunner.text = [NSString stringWithFormat:@"Racer Found: %@",effort.fullName];
            
        }
        else
        {
            self.lblRunner.text = @"Racer Not Found!";
            self.lblRunner.textColor = [UIColor redColor];
        }
    }

}

- (void)dealloc
{
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
}

@end
