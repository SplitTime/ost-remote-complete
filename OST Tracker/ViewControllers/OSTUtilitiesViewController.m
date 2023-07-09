//
//  OSTUtilitiesViewController.m
//  OST Remote
//
//  Created by Guillermo Apoj on 3/19/20.
//  Copyright © 2020 OST. All rights reserved.
//

#import "OSTUtilitiesViewController.h"
#import "OSTEventSelectionViewController.h"
#import "AppDelegate.h"
#import "UIView+Additions.h"
#import "CurrentCourse.h"
#import "EffortModel.h"

@interface OSTUtilitiesViewController ()
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (strong, nonatomic) IBOutlet UIView *loadingView;
@property (weak, nonatomic) IBOutlet UILabel *lblYourDataIsSynced;
@property (weak, nonatomic) IBOutlet UIImageView *imgCheckMark;
@property (weak, nonatomic) IBOutlet UILabel *lblSuccess;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet UIButton *btnReturnToLiveEntry;
@property (weak, nonatomic) IBOutlet UILabel *lblSyncing;
@property (weak, nonatomic) IBOutlet UIImageView *logoImage;
@property (weak, nonatomic) IBOutlet UILabel *remoteLbl;
@property (weak, nonatomic) IBOutlet UIButton *btnRetry;

@end

@implementation OSTUtilitiesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (IS_IPHONE_X || IS_IPHONE_XR)
    {
        self.lblTitle.numberOfLines = 1;
        self.lblTitle.bottom = self.lblTitle.bottom + 7;
        self.menuButton.bottom = self.menuButton.bottom + 7;
        
    }
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    self.loadingView.size = self.view.size;
}

- (void) showLoadingScreen
{
    [self showLoadingValues];
    self.loadingView.size = self.view.size;
    [self.view addSubview:self.loadingView];
    [self.view bringSubviewToFront:self.loadingView];
    self.loadingView.alpha = 0;
    
    __weak OSTUtilitiesViewController * weakSelf = self;
    [UIView animateWithDuration:0.5 animations:^{
        weakSelf.loadingView.alpha = 1;
    }];
}

- (void) showLoadingValues
{
    self.btnRetry.hidden = YES;
    self.imgCheckMark.hidden = YES;
    self.lblSuccess.hidden = YES;
    self.lblYourDataIsSynced.hidden = YES;
    self.btnReturnToLiveEntry.hidden = YES;
    
    [self.activityIndicator startAnimating];
    
    self.progressBar.hidden = NO;
    self.logoImage.hidden = NO;
    self.remoteLbl.hidden = NO;
    
}

- (void) showFinishLoadingValues
{
    self.imgCheckMark.image = [UIImage imageNamed:@"CheckMark"];
    self.imgCheckMark.hidden = NO;
    self.lblSuccess.text = @"Success!";
    self.lblSuccess.hidden = NO;
    self.lblYourDataIsSynced.text = @"The entrants data has been updated";
    self.lblYourDataIsSynced.hidden = NO;
    self.btnReturnToLiveEntry.hidden = NO;
   
    
    [self.activityIndicator stopAnimating];
    self.lblSyncing.hidden = YES;
    
    self.progressBar.hidden = YES;
    self.logoImage.hidden = YES;
    self.remoteLbl.hidden = YES;
}

- (void) showFinishLoadingErrorValues:(NSString*) error
{
    self.imgCheckMark.image = [UIImage imageNamed:@"Error-icon"];
    self.imgCheckMark.hidden = NO;
    self.lblSuccess.text = @"Failure!";
    self.lblSuccess.hidden = NO;
    self.lblYourDataIsSynced.text = error;
    self.lblYourDataIsSynced.hidden = NO;
    self.btnReturnToLiveEntry.hidden = NO;
    self.btnRetry.hidden = NO;
    
    [self.activityIndicator stopAnimating];
    self.lblSyncing.hidden = YES;
    
    self.progressBar.hidden = YES;
    self.logoImage.hidden = YES;
    self.remoteLbl.hidden = YES;
}
- (IBAction)onRefreshData:(id)sender {
    [self showLoadingScreen];
    self.progressBar.progress = 0.5;
    CurrentCourse * currentCourse = [CurrentCourse getCurrentCourse];
    
    __weak OSTUtilitiesViewController * weakSelf = self;
    [[AppDelegate getInstance].getNetworkManager getEventsDetails:currentCourse.eventId completionBlock:^(id object)
     {
        weakSelf.progressBar.progress = 1;
        [weakSelf.activityIndicator stopAnimating];
        
        
        currentCourse.dataEntryGroups = object[@"data"][@"attributes"][@"dataEntryGroups"];
        for (id dataObject in object[@"included"])
        {
            if ([dataObject[@"type"] isEqualToString:@"efforts"])
            {
                [EffortModel MR_importFromObject:dataObject];
            }
        }
        //        Remove from local storage entrants that were deleted from the event 
        NSArray *idList = [object[@"included"] valueForKey:@"id"];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"NOT(effortId IN %@)", idList];
        [EffortModel MR_deleteAllMatchingPredicate:predicate];
        
        
        currentCourse.monitorPacers = object[@"data"][@"attributes"][@"monitorPacers"];
        
        NSMutableDictionary * eventIdsAndSplits = [NSMutableDictionary new];
        NSMutableDictionary * eventShortNames = [NSMutableDictionary new];
        for (NSDictionary * dict in object[@"included"])
        {
            if ([dict[@"type"] isEqualToString:@"events"])
            {
                NSString *shortName = dict[@"attributes"][@"shortName"];
                if (shortName != nil && [shortName isKindOfClass:[NSString class]])
                {
                    eventShortNames[dict[@"id"]] = shortName;
                }
                NSMutableArray * arr = eventIdsAndSplits[dict[@"id"]];
                if (arr == nil)
                {
                    arr = [NSMutableArray new];
                }
                [arr addObject: dict[@"attributes"][@"parameterizedSplitNames"]];
                eventIdsAndSplits[dict[@"id"]] = arr;
            }
        }
        currentCourse.eventIdsAndSplits = eventIdsAndSplits;
        currentCourse.eventShortNames = eventShortNames;
         [UIView animateWithDuration:0.5 animations:^{
           [weakSelf showFinishLoadingValues];
         }];
        [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
        
        
    } errorBlock:^(NSError *error) {
       
       [UIView animateWithDuration:0.5 animations:^{
           [weakSelf showFinishLoadingErrorValues:error.localizedDescription];
        }];
    }];
}


- (IBAction)onReturnToLiveEntry:(id)sender
{
    [self.activityIndicator stopAnimating];
    self.loadingView.hidden = YES;
    [self.loadingView removeFromSuperview];
    [[AppDelegate getInstance] showTracker];
    
}

- (IBAction)onAbout:(id)sender {
    [[AppDelegate getInstance] showAbout];
}

- (IBAction)onMenu:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}

- (IBAction)onChangeStation:(id)sender
{
    OSTEventSelectionViewController * event = [[OSTEventSelectionViewController alloc] initWithNibName:nil bundle:nil];
    event.changeStation = YES;
    [self presentViewController:event animated:YES completion:nil];
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
            [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
            [[AppDelegate getInstance] logout];
        }
    }];
}

@end
