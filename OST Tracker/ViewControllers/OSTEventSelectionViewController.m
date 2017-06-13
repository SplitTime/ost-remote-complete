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

@interface OSTEventSelectionViewController ()
@property (weak, nonatomic) IBOutlet UIButton *btnNext;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtEvent;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtStation;

@end

@implementation OSTEventSelectionViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.txtEvent.isOptionalDropDown = NO;
    [self.txtEvent setItemList:[NSArray arrayWithObjects:@"London",@"Johannesburg",@"Moscow",@"Mumbai",@"Tokyo",@"Sydney", nil]];
    
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
    
    [self.txtStation setItemList:[NSArray arrayWithObjects:@"Johannesburg",@"Moscow",@"Mumbai",@"Tokyo",@"Sydney", nil]];
}

-(void)onDoneSelectedEvent
{
    [self.txtEvent resignFirstResponder];
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
