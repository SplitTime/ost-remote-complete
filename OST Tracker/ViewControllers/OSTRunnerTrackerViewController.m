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
#import "OSTSessionManager.h"
#import "EffortModel.h"
#import "UIView+Additions.h"

@interface OSTRunnerTrackerViewController ()

@property (weak, nonatomic) IBOutlet UITextField *txtBibNumber;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblTime;
@property (strong, nonatomic) NSTimer * timer;
@property (weak, nonatomic) IBOutlet UISwitch *swchPaser;
@property (weak, nonatomic) IBOutlet UIButton *btnLeft;
@property (weak, nonatomic) IBOutlet UIButton *btnRight;
@property (weak, nonatomic) IBOutlet UISwitch *swchStoppedHere;
@property (weak, nonatomic) IBOutlet UIView *pacerAndAidView;
@property (strong, nonatomic) NSString * splitId;
@property (weak, nonatomic) IBOutlet UILabel *lblRunnerInfo;
@property (strong, nonatomic) NSString * dayString;
@property (strong, nonatomic) EffortModel * racer;

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
    
    if (IS_IPHONE_5)
    {
        self.pacerAndAidView.top = self.pacerAndAidView.top - 25;
        self.btnLeft.top = self.btnLeft.top - 55;
        self.btnRight.top = self.btnRight.top - 55;
    }
}

-(void)onTick:(NSTimer *)timer
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    self.lblTime.text = [dateFormatter stringFromDate:[NSDate date]];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    self.dayString = [dateFormatter stringFromDate:[NSDate date]];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.txtBibNumber becomeFirstResponder];
    self.lblTitle.text = [CurrentCourse getCurrentCourse].splitName;
}

- (IBAction)onRight:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC showRightMenu:YES];
}

- (IBAction)onEntryButton:(id)sender
{
    if (self.txtBibNumber.text.length == 0)
    {
        [OHAlertView showAlertWithTitle:@"Error" message:@"Please type a BIB number" dismissButton:@"Ok"];
        return;
    }
    
    CurrentCourse * course = [CurrentCourse MR_findFirst];
    
    EntryModel * entry = [EntryModel MR_createEntity];
    entry.bibNumber = self.txtBibNumber.text;
    if (sender == self.btnLeft)
        entry.bitKey = @"in";
    else entry.bitKey = @"out";
    entry.splitId = self.splitId;
    int timezoneoffset = (int)([[NSTimeZone systemTimeZone] secondsFromGMT])/60/60;
    entry.absoluteTime = [NSString stringWithFormat:@"%@ %@%01d:00",self.dayString, self.lblTime.text,timezoneoffset];
    entry.displayTime = self.lblTime.text;
    if (self.swchPaser.on)
        entry.withPacer = @"true";
    else entry.withPacer = @"false";
    if (self.swchStoppedHere.on)
        entry.stoppedHere = @"true";
    else entry.stoppedHere = @"false";
    
    entry.courseName = course.eventName;
    entry.splitName = course.splitName;
    
    if (self.racer)
    {
        entry.fullName = self.racer.fullName;
    }
    
    entry.source = [NSString stringWithFormat:@"ost-remote-%@",[OSTSessionManager getUUIDString]];
    
    [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
    [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
    
    self.txtBibNumber.text = @"";
    
    [self txtBibNumberChanged:nil];
}

- (IBAction)txtBibNumberChanged:(id)sender
{
    self.racer = nil;
    self.lblRunnerInfo.textColor = [UIColor darkGrayColor];
    if (self.txtBibNumber.text.length == 0)
    {
        self.lblRunnerInfo.text = @"Add Bib Number to search for runner";
    }
    else
    {
        EffortModel * effort = [EffortModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber == %@", [NSDecimalNumber decimalNumberWithString:self.txtBibNumber.text]]];
        
        if (effort)
        {
            self.lblRunnerInfo.text = [NSString stringWithFormat:@"Racer Found: %@",effort.fullName];
            self.racer = effort;
        }
        else
        {
            self.lblRunnerInfo.text = @"Racer Not Found!";
            self.lblRunnerInfo.textColor = [UIColor redColor];
        }
    }
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
