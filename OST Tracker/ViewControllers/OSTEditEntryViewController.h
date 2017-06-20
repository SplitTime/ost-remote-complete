//
//  OSTEditEntryViewController.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/15/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IQDropDownTextField.h"
#import "EntryModel.h"

@interface OSTEditEntryViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *txtBibNumber;
@property (weak, nonatomic) IBOutlet UISwitch *swchPacer;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblRunner;
@property (weak, nonatomic) IBOutlet UISwitch *swchStoppedHere;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtDate;

- (IBAction)onBibNumberChanged:(id)sender;
- (void) configureWithEntry:(EntryModel*)entry;

@end
