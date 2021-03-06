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
#import "EffortModel.h"

@interface OSTEditEntryViewController : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *txtBibNumber;
@property (weak, nonatomic) IBOutlet UIButton *swchPacer;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblRunner;
@property (weak, nonatomic) IBOutlet UIButton *swchStoppedHere;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtDate;
@property (nonatomic, copy) void (^entryHasBeenDeletedBlock)(void);
@property (nonatomic, copy) void (^entryHasBeenUpdatedBlock)(EffortModel * effort);
@property (nonatomic, assign) BOOL creatingNew;
@property (weak, nonatomic) IBOutlet UIView *pacerAndAidView;
@property (weak, nonatomic) IBOutlet UILabel *lblWithPacer;

- (IBAction)onBibNumberChanged:(id)sender;
- (void) configureWithEntry:(EntryModel*)entry;

@end
