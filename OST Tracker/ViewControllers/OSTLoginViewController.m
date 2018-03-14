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
    
    UIToolbar* keyboardToolbar = [[UIToolbar alloc] init];
    [keyboardToolbar sizeToFit];
    UIBarButtonItem *flexBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];
    UIBarButtonItem *doneBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                      target:self action:@selector(onDoneInKeyboard)];
    keyboardToolbar.items = @[flexBarButton, doneBarButton];
    self.txtEmail.inputAccessoryView = keyboardToolbar;
    
    keyboardToolbar = [[UIToolbar alloc] init];
    [keyboardToolbar sizeToFit];
    flexBarButton = [[UIBarButtonItem alloc]
                     initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                     target:nil action:nil];
    doneBarButton = [[UIBarButtonItem alloc]
                     initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                     target:self action:@selector(onDoneInKeyboard)];
    keyboardToolbar.items = @[flexBarButton, doneBarButton];
    self.txtPassword.inputAccessoryView = keyboardToolbar;
    
    [self.txtEmail removeInputAssistant];
    [self.txtPassword removeInputAssistant];
}

-(void)onDoneInKeyboard
{
    [self.txtEmail resignFirstResponder];
    [self.txtPassword resignFirstResponder];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [IQKeyboardManager sharedManager].enable = YES;
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [IQKeyboardManager sharedManager].enable = YES;
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
    
    __weak OSTLoginViewController * weakSelf = self;
    [[AppDelegate getInstance].getNetworkManager loginWithEmail:self.txtEmail.text password:self.txtPassword.text completionBlock:^(id object)
    {
        weakSelf.progressBar.progress = 0.5;
        [OSTSessionManager setUserName:weakSelf.txtEmail.text andPassword:weakSelf.txtPassword.text];
        [[AppDelegate getInstance].getNetworkManager addTokenToHeader:object[@"token"]];
        if (weakSelf.completionBlock)
        {
            weakSelf.completionBlock(nil);
            [IQKeyboardManager sharedManager].enable = NO;
            [weakSelf dismissViewControllerAnimated:YES completion:nil];
        }
        else
        {
            [weakSelf loadEventData];
        }
    } errorBlock:^(NSError *error) {
        [weakSelf showLoginFields];
        
        if (error.errorsFromDictionary.length != 0)
        {
            [OHAlertView showAlertWithTitle:@"Unable to login" message:error.errorsFromDictionary dismissButton:@"Ok"];
        }
        else
        {
            [OHAlertView showAlertWithTitle:@"Unable to login" message:@"Please try again later when you have a data or wi-fi connection" dismissButton:@"Ok"];
        }
    }];
}

- (void) loadEventData
{
    OSTEventSelectionViewController * eventVC = [[OSTEventSelectionViewController alloc] initWithNibName:nil bundle:nil] ;
    
    __weak OSTLoginViewController * weakSelf = self;
    eventVC.tempContext = [NSManagedObjectContext MR_contextWithParent:[NSManagedObjectContext MR_defaultContext]];
    self.loadingLabel.text = @"Downloading Event Data";
    [[AppDelegate getInstance].getNetworkManager getAllEventsWithCompletionBlock:^(id object) {
    
        if ([object[@"data"] count] == 0)
        {
            [weakSelf showLoginFields];
            [[AppDelegate getInstance].getNetworkManager addTokenToHeader:nil];
            [OHAlertView showAlertWithTitle:@"No Events Available" message:@"You are not authorized for any live events. Make sure your event is enabled for live entry and that you are authorized as a steward." dismissButton:@"Ok"];
            return;
        }
        [weakSelf.activityIndicator stopAnimating];
        weakSelf.progressBar.progress = 1;
        
        NSMutableArray * pickerEvents = [NSMutableArray new];
        
        EventModel * eventToAdd = nil;
        for (id dataObject in object[@"data"])
        {
            eventToAdd = [EventModel MR_importFromObject:dataObject inContext:eventVC.tempContext];
            [pickerEvents addObject:eventToAdd];
        }
        
        [pickerEvents sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"startTime" ascending:NO]]];
        
        eventVC.events = pickerEvents;
        
        eventVC.eventStrings = [NSMutableArray new];
        
        for (EventModel * event in pickerEvents)
        {
            [eventVC.eventStrings addObject:event.name];
        }
        
        [IQKeyboardManager sharedManager].enable = NO;
        [weakSelf presentViewController:eventVC animated:YES completion:nil];
        
        [[NSUserDefaults standardUserDefaults] setObject:@(2) forKey:@"reviewScreenPicklistValue"];
        [[NSUserDefaults standardUserDefaults] synchronize];

    } progressBlock:^(NSProgress * _Nonnull uploadProgress) {
        
    } errorBlock:^(NSError *error) {
        [weakSelf showLoginFields];
        [OHAlertView showAlertWithTitle:@"Error" message:@"Couldn't get the events" cancelButton:@"Try Again" otherButtons:nil buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex) {
                [weakSelf loadEventData];
            }];
    }];
}

@end
