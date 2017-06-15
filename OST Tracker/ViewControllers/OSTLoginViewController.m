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

@interface OSTLoginViewController ()

@property (weak, nonatomic) IBOutlet UITextField *txtEmail;
@property (weak, nonatomic) IBOutlet UITextField *txtPassword;

@end //mariano.losangeles@gmail.com json9999

@implementation OSTLoginViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.txtEmail.text = [OSTSessionManager getStoredUserName];
    self.txtPassword.text = [OSTSessionManager getStoredPassword];
    
    //self.txtEmail.text = @"mariano.losangeles@gmail.com";
    //self.txtPassword.text = @"json9999";
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onLogin:(id)sender
{
    [DejalBezelActivityView activityViewForView:self.view];
    [[AppDelegate getInstance].getNetworkManager loginWithEmail:self.txtEmail.text password:self.txtPassword.text completionBlock:^(id object)
    {
        [OSTSessionManager setUserName:self.txtEmail.text andPassword:self.txtPassword.text];
        [[AppDelegate getInstance].getNetworkManager addTokenToHeader:object[@"token"]];
        [DejalBezelActivityView removeViewAnimated:YES];
        [self.navigationController pushViewController:[[OSTEventSelectionViewController alloc] initWithNibName:nil bundle:nil] animated:YES];
    } errorBlock:^(NSError *error) {
        [DejalBezelActivityView removeViewAnimated:YES];
        [OHAlertView showAlertWithTitle:@"Error" message:error.localizedDescription dismissButton:@"ok"];
    }];
}


@end
