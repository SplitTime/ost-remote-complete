//
//  OSTReviewSubmitViewController.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/15/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTReviewSubmitViewController.h"
#import "OSTNetworkManager+Login.h"
#import "OSTNetworkManager+Entries.h"
#import "EntryModel.h"

@interface OSTReviewSubmitViewController ()

@end

@implementation OSTReviewSubmitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (IBAction)onRightMenu:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC showRightMenu:YES];
}

- (IBAction)onSubmit:(id)sender
{
    NSArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"submitted == NIL"]];
    
    if (entries.count == 0)
    {
        [OHAlertView showAlertWithTitle:@"Error" message:@"Nothing to send" dismissButton:@"Ok"];
        return;
    }
    
    [DejalBezelActivityView activityViewForView:self.view];
    [[AppDelegate getInstance].getNetworkManager autoLoginWithCompletionBlock:^(id object) {
        [DejalBezelActivityView removeViewAnimated:YES];
        [[AppDelegate getInstance].getNetworkManager submitEntries:entries completionBlock:^(id object) {
            [DejalBezelActivityView removeViewAnimated:YES];
            [OHAlertView showAlertWithTitle:nil message:@"Submitted" dismissButton:@"Ok"];
            
            for (EntryModel * entry in entries)
            {
                entry.submitted = @(YES);
            }
            
            [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
            [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
            
        } errorBlock:^(NSError *error) {
            [DejalBezelActivityView removeViewAnimated:YES];
            [OHAlertView showAlertWithTitle:@"Error" message:@"Can't submit, try again later" dismissButton:@"Ok"];
        }];
    } errorBlock:^(NSError *error) {
        [DejalBezelActivityView removeViewAnimated:YES];
        [OHAlertView showAlertWithTitle:@"Error" message:@"Can't submit, try again later" dismissButton:@"Ok"];
    }];
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
