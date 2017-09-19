//
//  OSTEventSelectionViewController.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTEventSelectionViewController.h"
#import "IQDropDownTextField.h"
#import "OSTRunnerTrackerViewController.h"
#import "EventModel.h"
#import "CurrentCourse.h"
#import "CourseSplits.h"
#import "EffortModel.h"
#import "CourseSplits.h"
#import "IQKeyboardManager.h"

@interface OSTEventSelectionViewController ()
@property (weak, nonatomic) IBOutlet UILabel *progressLabel;
@property (weak, nonatomic) IBOutlet UILabel *lblSelectEvent;
@property (weak, nonatomic) IBOutlet UILabel *lblSelectAidStation;
@property (weak, nonatomic) IBOutlet UIButton *btnLogout;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIImageView *eventTriangle;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;

@end

@implementation OSTEventSelectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.txtEvent.isOptionalDropDown = NO;
    
    UIToolbar* keyboardToolbar = [[UIToolbar alloc] init];
    [keyboardToolbar sizeToFit];
    UIBarButtonItem *flexBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];
    UIBarButtonItem *doneBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                      target:self action:@selector(onDoneSelectedEvent)];
    keyboardToolbar.items = @[flexBarButton, doneBarButton];
    self.txtEvent.inputAccessoryView = keyboardToolbar;
    
    keyboardToolbar = [[UIToolbar alloc] init];
    [keyboardToolbar sizeToFit];
    flexBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];
    doneBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                      target:self action:@selector(onDoneSelectedStation)];
    keyboardToolbar.items = @[flexBarButton, doneBarButton];
    self.txtStation.inputAccessoryView = keyboardToolbar;
    
    self.btnNext.alpha = 0;
    self.txtStation.alpha = 0;
    
    if (self.changeStation)
    {
        self.eventTriangle.hidden = YES;
        self.lblSelectEvent.textAlignment = NSTextAlignmentCenter;
        self.lblSelectEvent.text = @"(Please logout to change events)";
        self.imgTriangleAidStation.hidden = NO;
        self.txtEvent.textAlignment = NSTextAlignmentCenter;
        self.txtEvent.font = [UIFont boldSystemFontOfSize:16];
        [self.btnNext setImage:[UIImage imageNamed:@"Live Entry"] forState:UIControlStateNormal];
    }
    else
    {
        self.btnCancel.hidden = YES;
        self.btnLogout.hidden = NO;
        self.txtEvent.layer.borderColor = [UIColor whiteColor].CGColor;
        self.txtEvent.layer.borderWidth = 1;
        self.txtEvent.layer.cornerRadius = 3;
    }
    
    self.txtStation.layer.borderColor = [UIColor whiteColor].CGColor;
    self.txtStation.layer.borderWidth = 1;
    self.txtStation.layer.cornerRadius = 3;
    
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 20)];
    self.txtStation.leftView = paddingView;
    self.txtStation.leftViewMode = UITextFieldViewModeAlways;
    
    UIView *paddingViewForPassword = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 20)];
    self.txtEvent.leftView = paddingViewForPassword;
    self.txtEvent.leftViewMode = UITextFieldViewModeAlways;
    
    CGAffineTransform transform = CGAffineTransformMakeScale(1.0f, 3.0f);
    self.progressBar.transform = transform;
    
    [IQKeyboardManager sharedManager].enable = YES;
    
    [self.txtStation removeInputAssistant];
    [self.txtEvent removeInputAssistant];
}

- (IBAction)onCancel:(id)sender
{
    [IQKeyboardManager sharedManager].enable = NO;
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    if (self.eventsLoaded)
    {
        return;
    }
    
    if (self.changeStation)
    {
        CurrentCourse * course = [CurrentCourse getCurrentCourse];
        self.txtEvent.userInteractionEnabled = NO;
        [self.txtEvent setItemList:@[course.eventName]];
        NSArray * stations = course.liveAttributes;
        NSMutableArray * stationStrings = [NSMutableArray new];
        for (NSDictionary * split in stations)
        {
            [stationStrings addObject:split[@"title"]];
        }
        [self.txtStation setItemList:stationStrings];
        [self.txtStation becomeFirstResponder];
        
        self.btnNext.alpha = 1;
        self.txtStation.alpha = 1;
        self.liveAttributes = course.liveAttributes;
        return;
    }
    
    [self.txtEvent setItemList:self.eventStrings];
    [self.txtEvent becomeFirstResponder];
    self.eventsLoaded = YES;
    
    if (self.eventStrings.count == 1)
    {
        [self onDoneSelectedEvent];
    }
}

-(void)onDoneSelectedEvent
{
    [self.txtEvent resignFirstResponder];
    
    NSMutableArray * splitStrings = [NSMutableArray new];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", self.txtEvent.selectedItem];
    NSArray *filteredArray = [self.events filteredArrayUsingPredicate:predicate];
    EventModel * firstFoundObject = nil;
    firstFoundObject =  filteredArray.count > 0 ? filteredArray.firstObject : nil;
    
    if (firstFoundObject == nil)
    {
        return;
    }
    
    self.selectedEvent = firstFoundObject;
    
    for (NSDictionary * liveEntry in self.selectedEvent.liveEntryAttributes)
    {
        [splitStrings addObject:liveEntry[@"title"]];
    }
    
    [self.txtStation setItemList:splitStrings];
    
    __weak OSTEventSelectionViewController * weakSelf = self;
    [UIView animateWithDuration:0.3 animations:^{
        weakSelf.txtStation.alpha = 1;
        weakSelf.imgTriangleAidStation.hidden = NO;
    }];
    
    [self.txtStation becomeFirstResponder];
}

-(void)onDoneSelectedStation
{
    [self.txtStation resignFirstResponder];
    __weak OSTEventSelectionViewController * weakSelf = self;
    [UIView animateWithDuration:0.8 animations:^{
        weakSelf.btnNext.alpha = 1;
    }];
}

- (void) showSelectFields
{
    self.lblSelectEvent.hidden = NO;
    self.lblSelectAidStation.hidden = NO;
    self.btnNext.hidden = NO;
    self.txtEvent.hidden = NO;
    self.txtStation.hidden = NO;
    self.eventTriangle.hidden = NO;
    self.imgTriangleAidStation.hidden = NO;
    
    self.progressLabel.hidden = YES;
    [self.activityIndicator stopAnimating];
    self.progressBar.hidden = YES;
}

- (void) showLoadingFields
{
    self.lblSelectEvent.hidden = YES;
    self.lblSelectAidStation.hidden = YES;
    self.btnNext.hidden = YES;
    self.txtEvent.hidden = YES;
    self.txtStation.hidden = YES;
    self.eventTriangle.hidden = YES;
    self.imgTriangleAidStation.hidden = YES;
    
    self.progressLabel.hidden = NO;
    [self.activityIndicator startAnimating];
    self.progressBar.hidden = NO;
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
            [[AppDelegate getInstance] logout];
        }
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onNext:(id)sender
{
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"title == %@", self.txtStation.selectedItem];
    NSArray *filteredArray = nil;
    
    if (!self.liveAttributes)
    {
        filteredArray = [self.selectedEvent.liveEntryAttributes filteredArrayUsingPredicate:predicate];
    }
    else
    {
        filteredArray = [self.liveAttributes filteredArrayUsingPredicate:predicate];
    }
    
    NSDictionary * firstFoundObject = nil;
    firstFoundObject =  filteredArray.count > 0 ? filteredArray.firstObject : nil;
    
    if (!firstFoundObject)
    {
        [OHAlertView showAlertWithTitle:@"" message:@"You need to select an aid station to continue." dismissButton:@"Ok"];
        return;
    }
    
    if (self.changeStation)
    {
        CurrentCourse * currentCourse = [CurrentCourse getCurrentCourse];
        currentCourse.splitId = [firstFoundObject[@"entries"][0][@"splitId"] stringValue];
        currentCourse.splitName = firstFoundObject[@"title"];
        currentCourse.splitAttributes = firstFoundObject;
        [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];

        [IQKeyboardManager sharedManager].enable = NO;

        [[AppDelegate getInstance] showTracker];
        [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
        
        [self dismissViewControllerAnimated:YES completion:^{
            
        }];
        return;
    }
    
    self.progressLabel.text = [NSString stringWithFormat:@"Downloading %@ Data",self.txtEvent.selectedItem];
    [self showLoadingFields];
    self.progressBar.progress = 0.5;
    
    __weak OSTEventSelectionViewController * weakSelf = self;
    [[AppDelegate getInstance].getNetworkManager getEventsDetails:self.selectedEvent.eventId completionBlock:^(id object)
    {
        weakSelf.progressBar.progress = 1;
        [weakSelf.activityIndicator stopAnimating];
        CurrentCourse * currentCourse = [CurrentCourse MR_createEntity];
        
        for (id dataObject in object[@"included"])
        {
            if ([dataObject[@"type"] isEqualToString:@"efforts"])
            {
                [EffortModel MR_importFromObject:dataObject];
            }
        }
        currentCourse.splitId = [firstFoundObject[@"entries"][0][@"splitId"] stringValue];
        currentCourse.eventId = weakSelf.selectedEvent.eventId;
        currentCourse.splitName = firstFoundObject[@"title"];
        currentCourse.eventName = weakSelf.selectedEvent.name;
        currentCourse.multiLap = weakSelf.selectedEvent.multiLap;
        currentCourse.splitAttributes = firstFoundObject;
        currentCourse.liveAttributes = weakSelf.selectedEvent.liveEntryAttributes;
        
        [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
        
        [[AppDelegate getInstance] loadLeftMenu];
    } errorBlock:^(NSError *error) {
        [weakSelf showSelectFields];
        [OHAlertView showAlertWithTitle:@"Error" message:@"Couldn't get course details" dismissButton:@"Ok"];
    }];
}

@end
