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
#import "IQKeyboardManager.h"

@interface OSTLoginViewController ()

@property (weak, nonatomic) IBOutlet UITextField *txtEmail;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet UILabel *lblUserName;
@property (weak, nonatomic) IBOutlet UILabel *lblPassword;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UILabel *loadingLabel;
@property (weak, nonatomic) IBOutlet UIButton *btnLogin;
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
    
    CGAffineTransform transform = CGAffineTransformMakeScale(1.0f, 3.0f);
    self.progressBar.transform = transform;
    
    UIView *paddingViewForPassword = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 20)];
    self.txtPassword.leftView = paddingViewForPassword;
    self.txtPassword.leftViewMode = UITextFieldViewModeAlways;
    [IQKeyboardManager sharedManager].enableAutoToolbar = YES;
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)endEditing:(id)sender
{
    [self.txtPassword becomeFirstResponder];
}

- (void) showLoginFields
{
    self.lblPassword.hidden = NO;
    self.lblUserName.hidden = NO;
    self.btnLogin.hidden = NO;
    self.txtEmail.hidden = NO;
    self.txtPassword.hidden = NO;
    
    self.loadingLabel.hidden = YES;
    [self.activityIndicator stopAnimating];
    self.progressBar.hidden = YES;
}

- (void) showLoadingFields
{
    self.lblPassword.hidden = YES;
    self.lblUserName.hidden = YES;
    self.btnLogin.hidden = YES;
    self.txtEmail.hidden = YES;
    self.txtPassword.hidden = YES;
    
    self.loadingLabel.hidden = NO;
    [self.activityIndicator startAnimating];
    self.progressBar.hidden = NO;
}

- (IBAction)onLogin:(id)sender
{
    [self.txtPassword resignFirstResponder];
    [self.txtEmail resignFirstResponder];
    [self showLoadingFields];
    self.loadingLabel.text = @"Trying to log in";
    [[AppDelegate getInstance].getNetworkManager loginWithEmail:self.txtEmail.text password:self.txtPassword.text completionBlock:^(id object)
    {
        self.progressBar.progress = 0.5;
        [OSTSessionManager setUserName:self.txtEmail.text andPassword:self.txtPassword.text];
        [[AppDelegate getInstance].getNetworkManager addTokenToHeader:object[@"token"]];
        if (self.completionBlock)
        {
            self.completionBlock(nil);
            [self dismissViewControllerAnimated:YES completion:nil];
        }
        else
        {
            [self loadEventData];
        }
    } errorBlock:^(NSError *error) {
        [self showLoginFields];
        [OHAlertView showAlertWithTitle:@"Unable to login" message:[NSString stringWithFormat:@"Please try again later when you have a data or wi-fi connection. %@", error.errorsFromDictionary] dismissButton:@"Ok"];
    }];
}

- (void) loadEventData
{
    OSTEventSelectionViewController * eventVC = [[OSTEventSelectionViewController alloc] initWithNibName:nil bundle:nil] ;
    
    eventVC.tempContext = [NSManagedObjectContext MR_contextWithParent:[NSManagedObjectContext MR_defaultContext]];
    self.loadingLabel.text = @"Downloading Event Data";
    [[AppDelegate getInstance].getNetworkManager getAllEventsWithCompletionBlock:^(id object) {
        [self.activityIndicator stopAnimating];
        self.progressBar.progress = 1;
        
        NSMutableArray * pickerEvents = [NSMutableArray new];
        
        for (id dataObject in object[@"data"])
        {
            [pickerEvents addObject:[EventModel MR_importFromObject:dataObject inContext:eventVC.tempContext]];
        }
        
        [pickerEvents sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"startTime" ascending:NO]]];
        
        eventVC.events = pickerEvents;
        
        eventVC.eventStrings = [NSMutableArray new];
        
        for (EventModel * event in pickerEvents)
        {
            [eventVC.eventStrings addObject:event.name];
        }
        
        [self presentViewController:eventVC animated:YES completion:nil];

    } progressBlock:^(NSProgress * _Nonnull uploadProgress) {
        
    } errorBlock:^(NSError *error) {
        [self showLoginFields];
        [OHAlertView showAlertWithTitle:@"Error" message:@"Couldn't get the events" cancelButton:@"Try Again" otherButtons:nil buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex) {
                [self loadEventData];
            }];
    }];
}

@end
