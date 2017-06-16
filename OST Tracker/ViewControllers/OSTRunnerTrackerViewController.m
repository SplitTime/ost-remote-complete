//
//  OSTRunnerTrackerViewController.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/13/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTRunnerTrackerViewController.h"
#import "EntryModel.h"
#import "CurrentCourse.h"

@interface OSTRunnerTrackerViewController ()

@property (weak, nonatomic) IBOutlet UITextField *txtBibNumber;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblTime;
@property (strong, nonatomic) NSTimer * timer;
@property (weak, nonatomic) IBOutlet UISwitch *swchPaser;
@property (weak, nonatomic) IBOutlet UISwitch *swchStoppedHere;
@property (strong, nonatomic) NSString * splitId;

@end

@implementation OSTRunnerTrackerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.timer = [NSTimer scheduledTimerWithTimeInterval: 0.5
                                                              target: self
                                                            selector:@selector(onTick:)
                                                            userInfo: nil repeats:YES];
    
    self.splitId = [CurrentCourse getCurrentCourse].splitId;
}

-(void)onTick:(NSTimer *)timer
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    self.lblTime.text = [dateFormatter stringFromDate:[NSDate date]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.txtBibNumber becomeFirstResponder];
}

- (IBAction)onRight:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC showRightMenu:YES];
}

- (IBAction)onLeftButton:(id)sender
{
    if (self.txtBibNumber.text.length == 0)
    {
        [OHAlertView showAlertWithTitle:@"Error" message:@"Please type a bid number" dismissButton:@"Ok"];
        return;
    }
    
    EntryModel * entry = [EntryModel MR_createEntity];
    entry.bibNumber = self.txtBibNumber.text;
    entry.bitKey = @"1";
    entry.splitId = self.splitId;
    int timezoneoffset = (int)([[NSTimeZone systemTimeZone] secondsFromGMT])/60/60;
    entry.absoluteTime = [NSString stringWithFormat:@"%@%01d:00",self.lblTime.text,timezoneoffset];
    if (self.swchPaser.on)
        entry.withPacer = @"true";
    else entry.withPacer = @"false";
    if (self.swchStoppedHere.on)
        entry.stoppedHere = @"true";
    else entry.stoppedHere = @"false";
    
    entry.source = @"ost-remote-88581b60112003f4e3ce60981756abfc";
    
    [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
    [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
    
    self.txtBibNumber.text = @"";
}

- (IBAction)onRightButton:(id)sender
{
    if (self.txtBibNumber.text.length == 0)
    {
        [OHAlertView showAlertWithTitle:@"Error" message:@"Please type a bid number" dismissButton:@"Ok"];
        return;
    }
    
    EntryModel * entry = [EntryModel MR_createEntity];
    entry.bibNumber = self.txtBibNumber.text;
    entry.bitKey = @"64";
    entry.splitId = self.splitId;
    int timezoneoffset = (int)([[NSTimeZone systemTimeZone] secondsFromGMT])/60/60;
    entry.absoluteTime = [NSString stringWithFormat:@"%@%01d:00",self.lblTime.text,timezoneoffset];
    if (self.swchPaser.on)
        entry.withPacer = @"true";
    else entry.withPacer = @"false";
    if (self.swchStoppedHere.on)
        entry.stoppedHere = @"true";
    else entry.stoppedHere = @"false";
    
    entry.source = @"ost-remote-88581b60112003f4e3ce60981756abfc";
    
    [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
    [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
    
    self.txtBibNumber.text = @"";
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
