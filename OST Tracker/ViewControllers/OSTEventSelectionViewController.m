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

@interface OSTEventSelectionViewController ()
@property (weak, nonatomic) IBOutlet UIButton *btnNext;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtEvent;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtStation;
@property (strong, nonatomic) NSMutableArray * events;

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
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [DejalBezelActivityView activityViewForView:self.view];
    [[AppDelegate getInstance].getNetworkManager getAllEventsWithCompletionBlock:^(id object) {
        [DejalBezelActivityView removeViewAnimated:YES];
        
        NSMutableArray * pickerEvents = [NSMutableArray new];
        for (id dataObject in object[@"data"])
        {
            [pickerEvents addObject:[EventModel MR_importFromObject:dataObject]];
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
    
    NSMutableArray * aidStations = [NSMutableArray new];
    
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", self.txtEvent.selectedItem];
    NSArray *filteredArray = [self.events filteredArrayUsingPredicate:predicate];
    EventModel * firstFoundObject = nil;
    firstFoundObject =  filteredArray.count > 0 ? filteredArray.firstObject : nil;
    
    for (NSDictionary * dictionary in firstFoundObject.aidStations)
    {
        [aidStations addObject:dictionary[@"id"]];
    }
    
    [self.txtStation setItemList:aidStations];
    
    [self.txtStation becomeFirstResponder];
    
}

-(void)onDoneSelectedStation
{
    [self.txtStation resignFirstResponder];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onNext:(id)sender
{
    [self.navigationController pushViewController:[[OSTRunnerTrackerViewController alloc] initWithNibName:nil bundle:nil] animated:YES];
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
