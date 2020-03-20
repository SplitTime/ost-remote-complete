//
//  OSTUtilitiesViewController.m
//  OST Remote
//
//  Created by Guillermo Apoj on 3/19/20.
//  Copyright © 2020 OST. All rights reserved.
//

#import "OSTUtilitiesViewController.h"
#import "OSTEventSelectionViewController.h"
#import "AppDelegate.h"

@interface OSTUtilitiesViewController ()
//@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@end

@implementation OSTUtilitiesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

 - (IBAction)onMenu:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}

- (IBAction)onChangeStation:(id)sender
{
    //[[AppDelegate getInstance].rightMenuVC switchRightMenu:NO];
    OSTEventSelectionViewController * event = [[OSTEventSelectionViewController alloc] initWithNibName:nil bundle:nil];
    event.changeStation = YES;
    [self presentViewController:event animated:YES completion:nil];
}

- (IBAction)onLogout:(id)sender
{
    if (![AppDelegate getInstance].getNetworkManager.reachabilityManager.reachable)
    {
        [OHAlertView showAlertWithTitle:@"Logout is disabled" message:@"Please try again when you have an Internet connection" cancelButton:@"Ok" otherButtons:nil buttonHandler:nil];
        return;
    }

    [OHAlertView showAlertWithTitle:@"Are you sure you would like to log out?" message:@"You will not be able to log back in or add entries until you have a data connection again." cancelButton:@"Cancel" otherButtons:@[@"Logout"] buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex) {
        if (buttonIndex == 1)
        {
            [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
            [[AppDelegate getInstance] logout];
        }
    }];
}

@end
