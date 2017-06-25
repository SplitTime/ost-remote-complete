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

@interface OSTEventSelectionViewController ()
@property (weak, nonatomic) IBOutlet UIButton *btnNext;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtEvent;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtStation;
@property (strong, nonatomic) NSManagedObjectContext * tempContext;
@property (strong, nonatomic) NSMutableArray * events;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;
@property (strong, nonatomic) EventModel * selectedEvent;
@property (strong, nonatomic) NSArray * liveAttributes;
@property (weak, nonatomic) IBOutlet UIImageView *imgTriangleAidStation;

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
    
    if (!self.changeStation)
    {
        self.btnCancel.hidden = YES;
    }
    
    self.txtStation.layer.borderColor = [UIColor whiteColor].CGColor;
    self.txtStation.layer.borderWidth = 1;
    self.txtStation.layer.cornerRadius = 3;
    
    self.txtEvent.layer.borderColor = [UIColor whiteColor].CGColor;
    self.txtEvent.layer.borderWidth = 1;
    self.txtEvent.layer.cornerRadius = 3;
    
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 20)];
    self.txtStation.leftView = paddingView;
    self.txtStation.leftViewMode = UITextFieldViewModeAlways;
    
    UIView *paddingViewForPassword = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 20)];
    self.txtEvent.leftView = paddingViewForPassword;
    self.txtEvent.leftViewMode = UITextFieldViewModeAlways;

}

- (IBAction)onCancel:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) viewDidAppear:(BOOL)animated
{
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
    
    [super viewDidAppear:animated];
    
    self.tempContext = [NSManagedObjectContext MR_contextWithParent:[NSManagedObjectContext MR_defaultContext]];
    
    [DejalBezelActivityView activityViewForView:self.view];
    [[AppDelegate getInstance].getNetworkManager getAllEventsWithCompletionBlock:^(id object) {
        [DejalBezelActivityView removeViewAnimated:YES];
        
        NSMutableArray * pickerEvents = [NSMutableArray new];
        
        for (id dataObject in object[@"data"])
        {
            [pickerEvents addObject:[EventModel MR_importFromObject:dataObject inContext:self.tempContext]];
        }
        
        [pickerEvents sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"startTime" ascending:NO]]];
        
        self.events = pickerEvents;
        
        NSMutableArray * eventStrings = [NSMutableArray new];
        
        for (EventModel * event in pickerEvents)
        {
            [eventStrings addObject:event.name];
        }
        
        [self.txtEvent setItemList:eventStrings];
        [self.txtEvent becomeFirstResponder];
        
    } errorBlock:^(NSError *error) {
        [DejalBezelActivityView removeViewAnimated:YES];
    }];
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
    
    [UIView animateWithDuration:0.3 animations:^{
        self.txtStation.alpha = 1;
        self.imgTriangleAidStation.hidden = NO;
    }];
    
    [self.txtStation becomeFirstResponder];
}

-(void)onDoneSelectedStation
{
    [self.txtStation resignFirstResponder];
    [UIView animateWithDuration:0.8 animations:^{
        self.btnNext.alpha = 1;
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
        [OHAlertView showAlertWithTitle:@"Error" message:@"Please Select a Split" dismissButton:@"Ok"];
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

        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }
    
    [DejalBezelActivityView activityViewForView:self.view];
    [[AppDelegate getInstance].getNetworkManager getEventsDetails:self.selectedEvent.eventId completionBlock:^(id object)
    {
        [DejalBezelActivityView removeViewAnimated:YES];
        CurrentCourse * currentCourse = [CurrentCourse MR_createEntity];
        
        for (id dataObject in object[@"included"])
        {
            if ([dataObject[@"type"] isEqualToString:@"efforts"])
            {
                [EffortModel MR_importFromObject:dataObject];
            }
        }
        currentCourse.splitId = [firstFoundObject[@"entries"][0][@"splitId"] stringValue];
        currentCourse.eventId = self.selectedEvent.eventId;
        currentCourse.splitName = firstFoundObject[@"title"];
        currentCourse.eventName = self.selectedEvent.name;
        currentCourse.multiLap = self.selectedEvent.multiLap;
        currentCourse.splitAttributes = firstFoundObject;
        currentCourse.liveAttributes = self.selectedEvent.liveEntryAttributes;
        
        [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
        
        [[AppDelegate getInstance] loadLeftMenu];
    } errorBlock:^(NSError *error) {
        [DejalBezelActivityView removeViewAnimated:YES];
        [OHAlertView showAlertWithTitle:@"Error" message:@"Couldn't get course details" dismissButton:@"Ok"];
    }];
}

@end
