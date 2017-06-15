//
//  OSTRunnerTrackerViewController.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/13/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTRunnerTrackerViewController.h"

@interface OSTRunnerTrackerViewController ()

@property (weak, nonatomic) IBOutlet UITextField *txtBibNumber;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblTime;
@property (strong, nonatomic) NSTimer * timer;

@end

@implementation OSTRunnerTrackerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.timer = [NSTimer scheduledTimerWithTimeInterval: 0.5
                                                              target: self
                                                            selector:@selector(onTick:)
                                                            userInfo: nil repeats:YES];
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
