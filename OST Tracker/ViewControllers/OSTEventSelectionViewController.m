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

@interface OSTEventSelectionViewController ()
@property (weak, nonatomic) IBOutlet UIButton *btnNext;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtEvent;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtStation;
@property (strong, nonatomic) NSManagedObjectContext * tempContext;
@property (strong, nonatomic) NSMutableArray * events;
@property (strong, nonatomic) NSMutableArray * splits;
@property (strong, nonatomic) NSArray * eventSplits;
@property (strong, nonatomic) NSString * eventId;

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
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.tempContext = [NSManagedObjectContext MR_contextWithParent:[NSManagedObjectContext MR_defaultContext]];
    
    [DejalBezelActivityView activityViewForView:self.view];
    [[AppDelegate getInstance].getNetworkManager getAllEventsWithCompletionBlock:^(id object) {
        [DejalBezelActivityView removeViewAnimated:YES];
        
        NSMutableArray * pickerEvents = [NSMutableArray new];
        self.splits = [NSMutableArray new];
        for (id dataObject in object[@"data"])
        {
            [pickerEvents addObject:[EventModel MR_importFromObject:dataObject inContext:self.tempContext]];
        }
        for (id dataObject in object[@"included"])
        {
            [self.splits addObject:[CourseSplits MR_importFromObject:dataObject inContext:self.tempContext]];
        }
        
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
    
    NSMutableArray * splitIdsToSearch = [NSMutableArray new];
    for (NSDictionary * dictionary in firstFoundObject.splits)
    {
        [splitIdsToSearch addObject:dictionary[@"id"]];
    }
    
    self.eventSplits = [self.splits filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"splitId IN %@",splitIdsToSearch]];
    
    for (CourseSplits * split in self.eventSplits)
    {
        [splitStrings addObject:split.baseName];
    }
    
    [self.txtStation setItemList:splitStrings];
    
    [UIView animateWithDuration:0.3 animations:^{
        self.txtStation.alpha = 1;
    }];
    
    self.eventId = firstFoundObject.eventId;
    
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
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"baseName == %@", self.txtStation.selectedItem];
    NSArray *filteredArray = [self.splits filteredArrayUsingPredicate:predicate];
    CourseSplits * firstFoundObject = nil;
    firstFoundObject =  filteredArray.count > 0 ? filteredArray.firstObject : nil;
    
    CurrentCourse * currentCourse = [CurrentCourse MR_createEntity];
    
    currentCourse.splitId = firstFoundObject.splitId;
    currentCourse.eventId = self.eventId;
    [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
    [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
    
    [[AppDelegate getInstance] loadLeftMenu];
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
