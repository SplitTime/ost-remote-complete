//
//  OSTLoginViewController.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTLoginViewController.h"
#import "OSTEventSelectionViewController.h"
#import "OSTSessionManager.h"
#import "CurrentCourse.h"

@interface OSTLoginViewController ()

@property (weak, nonatomic) IBOutlet UITextField *txtEmail;
@property (weak, nonatomic) IBOutlet UITextField *txtPassword;

@end

@implementation OSTLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.txtEmail.text = [OSTSessionManager getStoredUserName];
    self.txtPassword.text = [OSTSessionManager getStoredPassword];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)endEditing:(id)sender
{
    [self.txtPassword becomeFirstResponder];
}

- (IBAction)onLogin:(id)sender
{
    [self.txtPassword resignFirstResponder];
    [self.txtEmail resignFirstResponder];
    [DejalBezelActivityView activityViewForView:self.view];
    [[AppDelegate getInstance].getNetworkManager loginWithEmail:self.txtEmail.text password:self.txtPassword.text completionBlock:^(id object)
    {
        [OSTSessionManager setUserName:self.txtEmail.text andPassword:self.txtPassword.text];
        [[AppDelegate getInstance].getNetworkManager addTokenToHeader:object[@"token"]];
        [DejalBezelActivityView removeViewAnimated:YES];
        if ([CurrentCourse getCurrentCourse])
        {
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        else
        {
            [self presentViewController:[[OSTEventSelectionViewController alloc] initWithNibName:nil bundle:nil] animated:YES completion:nil];
        }
    } errorBlock:^(NSError *error) {
        [DejalBezelActivityView removeViewAnimated:YES];
        [OHAlertView showAlertWithTitle:@"Error" message:error.localizedDescription dismissButton:@"ok"];
    }];
}


@end
