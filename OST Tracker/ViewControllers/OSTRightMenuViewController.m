//
//  OSTRightMenuViewController.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/15/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTRightMenuViewController.h"
#import "OSTEventSelectionViewController.h"
#import "OSTRunnerTrackerViewController.h"

@interface OSTRightMenuViewController ()

@end

@implementation OSTRightMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onClose:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC hideMenu:YES];
    
    if ([[AppDelegate getInstance].rightMenuVC.contentViewController isKindOfClass:[OSTRunnerTrackerViewController class]])
    {
        [((OSTRunnerTrackerViewController*)([AppDelegate getInstance].rightMenuVC.contentViewController)).txtBibNumber becomeFirstResponder];
    }
}

- (IBAction)onSubmit:(id)sender
{
    [[AppDelegate getInstance] showTracker];
    [[AppDelegate getInstance].rightMenuVC switchRightMenu:NO];
}

- (IBAction)onChangeStation:(id)sender
{
    //[[AppDelegate getInstance].rightMenuVC switchRightMenu:NO];
    OSTEventSelectionViewController * event = [[OSTEventSelectionViewController alloc] initWithNibName:nil bundle:nil];
    event.changeStation = YES;
    [self presentViewController:event animated:YES completion:nil];
}

- (IBAction)onReviewSync:(id)sender
{
    [[AppDelegate getInstance] showReview];
    [[AppDelegate getInstance].rightMenuVC switchRightMenu:NO];
}

- (IBAction)onLogout:(id)sender
{
    [OHAlertView showAlertWithTitle:@"Are you sure you would like to log out?" message:@"You will not be able to log back in or add entries until you have a data connection again." cancelButton:@"Cancel" otherButtons:@[@"Logout"] buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex) {
        if (buttonIndex == 1)
        {
            [[AppDelegate getInstance].rightMenuVC switchRightMenu:NO];
            [[AppDelegate getInstance] logout];
        }
    }];
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
