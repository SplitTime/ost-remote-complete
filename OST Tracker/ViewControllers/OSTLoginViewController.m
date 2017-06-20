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
    
    self.txtEmail.layer.borderColor = [UIColor whiteColor].CGColor;
    self.txtEmail.layer.borderWidth = 1;
    self.txtEmail.layer.cornerRadius = 3;
    
    self.txtPassword.layer.borderColor = [UIColor whiteColor].CGColor;
    self.txtPassword.layer.borderWidth = 1;
    self.txtPassword.layer.cornerRadius = 3;
    
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 20)];
    self.txtEmail.leftView = paddingView;
    self.txtEmail.leftViewMode = UITextFieldViewModeAlways;
    
    UIView *paddingViewForPassword = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 20)];
    self.txtPassword.leftView = paddingViewForPassword;
    self.txtPassword.leftViewMode = UITextFieldViewModeAlways;
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
