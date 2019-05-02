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
#import "OSTReviewTableViewCell.h"
#import "OSTEditEntryViewController.h"
#import "CurrentCourse.h"
#import "IQDropDownTextField.h"
#import "OSTReviewSectionHeader.h"
#import "UIView+Additions.h"
#import "CHCSVParser.h"
#import "OSTSyncManager.h"

@interface OSTReviewSubmitViewController () <OSTSyncManagerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblSyncing;
@property (strong, nonatomic) IBOutlet UIView *loadingView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UIButton *btnRightMenu;
@property (weak, nonatomic) IBOutlet UILabel *lblYourDataIsSynced;
@property (weak, nonatomic) IBOutlet UIImageView *imgCheckMark;
@property (weak, nonatomic) IBOutlet UILabel *lblSuccess;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet UIButton *btnReturnToLiveEntry;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtSortBy;
@property (weak, nonatomic) IBOutlet UIButton *btnSync;
@property (strong, nonatomic) NSMutableArray * entries;
@property (strong, nonatomic) NSMutableArray * splitTitles;
@property (weak, nonatomic) IBOutlet UILabel *lblBadge;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *syncIndicator;

@end

@implementation OSTReviewSubmitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Do any additional setup after loading the view from its nib.
    [self.tableView registerNib: [UINib nibWithNibName:@"OSTReviewTableViewCell" bundle:nil] forCellReuseIdentifier:@"OSTReviewTableViewCell"];
    
    self.txtSortBy.isOptionalDropDown = NO;
    self.txtSortBy.layer.borderColor = [UIColor whiteColor].CGColor;
    self.txtSortBy.layer.borderWidth = 1;
    self.txtSortBy.layer.cornerRadius = 3;
    
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 5, 20)];
    self.txtSortBy.leftView = paddingView;
    self.txtSortBy.leftViewMode = UITextFieldViewModeAlways;
    
    [self.txtSortBy setItemList:@[@"Name", @"Time Displayed", @"Time Entered", @"Bib #"]];
    
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"reviewScreenPicklistValue"])
    {
        self.txtSortBy.selectedRow = [[[NSUserDefaults standardUserDefaults] objectForKey:@"reviewScreenPicklistValue"] integerValue];
    }
    else
    {
        self.txtSortBy.selectedRow = 2;
    }
    
    UIToolbar* keyboardToolbar = [[UIToolbar alloc] init];
    [keyboardToolbar sizeToFit];
    UIBarButtonItem *flexBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                      target:nil action:nil];
    UIBarButtonItem *doneBarButton = [[UIBarButtonItem alloc]
                                      initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                      target:self action:@selector(onDoneSelectedSortBy:)];
    keyboardToolbar.items = @[flexBarButton, doneBarButton];
    self.txtSortBy.inputAccessoryView = keyboardToolbar;
    
    [self.txtSortBy removeInputAssistant];
    [self.btnSync setBackgroundImage:[UIImage imageNamed:@"GrayButton"] forState:UIControlStateHighlighted];
    if (IS_IPHONE_X)
    {
        self.lblTitle.numberOfLines = 1;
        self.lblTitle.bottom = self.lblTitle.bottom + 7;
        self.btnRightMenu.bottom = self.btnRightMenu.bottom + 7;
    }
    
    self.lblBadge.layer.cornerRadius = self.lblBadge.width/2;
    self.lblBadge.clipsToBounds = YES;
    
    [[OSTSyncManager shared] setShowToastOnCompletion:YES];
    
    [self updateSyncButtonState];
}

- (void) onDoneSelectedSortBy:(id) sender
{
    [[NSUserDefaults standardUserDefaults] setObject:@(self.txtSortBy.selectedRow) forKey:@"reviewScreenPicklistValue"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.txtSortBy resignFirstResponder];
    [self loadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:YES];
    self.loadingView.size = self.view.size;
    [self loadData];
    [self updateSyncBadge];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[OSTSyncManager shared] setShowToastOnCompletion:YES];
}

- (IBAction)onExport:(id)sender
{
    NSMutableArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@ && submitted == NIL && bibNumber != %@",[CurrentCourse getCurrentCourse].eventId,@"-1"]].mutableCopy;
    if (entries.count == 0)
    {
        if (self.entries.count == 0)
            [OHAlertView showAlertWithTitle:@"" message:@"No times have been entered." dismissButton:@"Ok"];
        else [OHAlertView showAlertWithTitle:@"" message:@"All times have been synced." dismissButton:@"Ok"];
        return;
    }
    
    [OHAlertView showAlertWithTitle:@"" message:@"This feature exports data to the local device only. It does not sync with OpenSplitTime.org" cancelButton:@"Ok" otherButtons:nil buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex)
    {
        NSMutableArray * entriesArrayDict = [NSMutableArray new];
        for (EntryModel * entry in entries)
        {
            [entriesArrayDict addObject:@{@"type": @"raw_time",
                                          @"attributes": @{
                                                  @"splitName": entry.splitName,
                                                  @"subSplitKind": entry.bitKey,
                                                  @"bibNumber": entry.bibNumber,
                                                  @"absoluteTime": entry.absoluteTime,
                                                  @"withPacer": entry.withPacer,
                                                  @"stoppedHere": entry.stoppedHere,
                                                  @"source": entry.source
                                                  }}];
        }
        
        // Create in memory writer
        NSOutputStream *stream = [NSOutputStream outputStreamToMemory];
        CHCSVWriter *writer = [[CHCSVWriter alloc] initWithOutputStream:stream
                                                               encoding:NSUTF8StringEncoding
                                                              delimiter:','];
        
        // Construct csv
        
        // Write header...
        NSArray *keys = @[@"splitName",@"subSplitKind",@"bibNumber",@"absoluteTime",@"withPacer",@"stoppedHere",@"source"];
        [writer writeLineOfFields:keys];
        
        // ...then fill the rows
        for (NSDictionary *item in entriesArrayDict) {
            /*for (NSString *key in keys) {
                NSString *value = [item[@"attributes"] objectForKey:key];
                [writer writeField:value];
            }*/
            [writer writeField:item[@"attributes"][@"splitName"]];
            [writer writeField:item[@"attributes"][@"subSplitKind"]];
            [writer writeField:item[@"attributes"][@"bibNumber"]];
            [writer writeField:item[@"attributes"][@"absoluteTime"]];
            [writer writeField:item[@"attributes"][@"withPacer"]];
            [writer writeField:item[@"attributes"][@"stoppedHere"]];
            [writer writeField:item[@"attributes"][@"source"]];
            
            [writer finishLine];
        }
        [writer closeStream];
        
        // Debug: Convert stream to string and print
        NSData *contents = [stream propertyForKey:NSStreamDataWrittenToMemoryStreamKey];
        
        NSString *csvString = [[NSString alloc] initWithData:contents
                                                    encoding:NSUTF8StringEncoding];
        
        NSArray *activityItems = @[csvString];
        UIActivityViewController *activityViewControntroller = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
        activityViewControntroller.excludedActivityTypes = @[];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            activityViewControntroller.popoverPresentationController.sourceView = self.view;
            activityViewControntroller.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2, self.view.bounds.size.height/4, 0, 0);
        }
        [self presentViewController:activityViewControntroller animated:true completion:nil];
    }];
}

- (void) loadData
{
    self.entries = [NSMutableArray new];
    NSArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@",[CurrentCourse getCurrentCourse].eventId]];
    
    NSMutableSet * set = [NSMutableSet new];
    
    for (EntryModel * entry in entries)
    {
        [set addObject:entry.splitName];
    }
    
    self.splitTitles = set.allObjects.mutableCopy;
    
    entries = nil;
    
    NSMutableArray * splitEntries = nil;
    
    NSString * sortKey = @"fullName";
    
    BOOL ascending = YES;
    
    if (self.txtSortBy.selectedRow == 0)
    {
        sortKey = @"fullName";
    }
    else if (self.txtSortBy.selectedRow == 1)
    {
        ascending = NO;
        sortKey = @"entryTime";
    }
    else if (self.txtSortBy.selectedRow == 2)
    {
        ascending = NO;
        sortKey = @"timeEntered";
    }
    else if (self.txtSortBy.selectedRow == 3)
    {
        sortKey = @"bibNumberDecimal";
    }
    
    if ([self.splitTitles containsObject:[CurrentCourse getCurrentCourse].splitName])
    {
        [self.splitTitles removeObject:[CurrentCourse getCurrentCourse].splitName];
        [self.splitTitles insertObject:[CurrentCourse getCurrentCourse].splitName atIndex:0];
    }
    
    for (NSString * title in self.splitTitles)
    {
        splitEntries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@ && splitName == %@",[CurrentCourse getCurrentCourse].eventId,title]].mutableCopy;
        [splitEntries sortUsingComparator:^NSComparisonResult(EntryModel *  _Nonnull obj1, EntryModel *  _Nonnull obj2) {
            
            if (obj1.bibNumber == nil) {
                return NSOrderedDescending;
            }
            
            if (obj2.bibNumber == nil) {
                return NSOrderedAscending;
            }
            
            return [[NSNumber numberWithInt:[obj1.bibNumber integerValue]] compare:[NSNumber numberWithInt:[obj2.bibNumber integerValue]]];
            
        }];
        [self.entries addObject:splitEntries];
    }
    
    
    self.lblTitle.text = [CurrentCourse getCurrentCourse].eventName;

    [self.tableView reloadData];
}

- (void) showLoadingScreen
{
    self.loadingView.size = self.view.size;
    [self.view addSubview:self.loadingView];
    [self.view bringSubviewToFront:self.loadingView];
    self.loadingView.alpha = 0;
    __weak OSTReviewSubmitViewController * weakSelf = self;
    [UIView animateWithDuration:0.5 animations:^{
        weakSelf.loadingView.alpha = 1;
    }];
}

- (void) showLoadingValues
{
    self.imgCheckMark.hidden = YES;
    self.lblSuccess.hidden = YES;
    self.lblYourDataIsSynced.hidden = YES;
    self.btnReturnToLiveEntry.top = self.progressBar.bottom + 20;
    
    [self.activityIndicator startAnimating];
    self.lblSyncing.hidden = NO;
    self.progressBar.hidden = NO;
    
    [[OSTSyncManager shared] setShowToastOnCompletion:NO];
}

- (void) showFinishLoadingValues
{
    self.imgCheckMark.hidden = NO;
    self.lblSuccess.hidden = NO;
    self.lblYourDataIsSynced.hidden = NO;
    self.btnReturnToLiveEntry.top = self.lblSuccess.bottom + 50;
    
    [self.activityIndicator stopAnimating];
    self.lblSyncing.hidden = YES;
    self.progressBar.hidden = YES;
}

- (IBAction)onRightMenu:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}

- (IBAction)onReturnToLiveEntry:(id)sender
{
    [self.activityIndicator stopAnimating];
    self.loadingView.hidden = YES;
    [self.loadingView removeFromSuperview];
    [[AppDelegate getInstance] showTracker];
}

- (void)updateSyncButtonState
{
    BOOL isSyncing = [[OSTSyncManager shared] isSyncing];
    [self.btnSync setEnabled:!isSyncing];
    [self.btnSync setAlpha:(isSyncing) ? 0.7 : 1];
    [self.syncIndicator setHidden:!isSyncing];
    
    if (isSyncing)
    {
        [self showLoadingValues];
    }
    else
    {
        [self showFinishLoadingValues];
    }
}

- (void)updateSyncBadge
{
    [super updateSyncBadge];
    self.lblBadge.hidden = self.badgeLabel.hidden;
    self.lblBadge.text = self.badgeLabel.text;
}

- (void)syncManagerDidStartSynchronization:(OSTSyncManager *)manager
{
    [super syncManagerDidStartSynchronization:manager];
    [self updateSyncButtonState];
}

- (void)syncManager:(OSTSyncManager *)manager progress:(CGFloat)progress
{
    [super syncManager:manager progress:progress];
    self.progressBar.progress = progress;
}

- (void)syncManagerDidFinishSynchronization:(OSTSyncManager *)manager
{
    [super syncManagerDidFinishSynchronization:manager];
    [self updateSyncButtonState];
    
    if (self.loadingView.superview != nil) {
        [self showFinishLoadingValues];
    }
    
    [self loadData];
}

- (void)syncManager:(OSTSyncManager *)manager didFinishSynchronizationWithErrors:(NSArray<NSError *> *)errors alternateServer:(BOOL)alternateServer
{
    [super syncManager:manager didFinishSynchronizationWithErrors:errors alternateServer:alternateServer];
    [self updateSyncButtonState];
    
    if (!alternateServer)
    {
        NSError *error = [errors firstObject];
        [OHAlertView showAlertWithTitle:@"Unable to sync" message:[NSString stringWithFormat:@"%@",[error errorsFromDictionary]] dismissButton:@"Ok"];
    }
    else
    {
        NSError *error1 = [errors objectAtIndex:0];
        NSString * errorMessage1 = nil;
        if (error1.code == -1009)
        {
            errorMessage1 = @"The device is not connected";
        }
        else
        {
            errorMessage1 = [NSString stringWithFormat:@"Error: %@",[error1 errorsFromDictionary]];
        }
        
        NSError *error2 = [errors objectAtIndex:1];
        NSString *errorMessage2 = [NSString stringWithFormat:@"Error: %@",[error2 errorsFromDictionary]];
        NSString * errorMessage = [NSString stringWithFormat:@"Primary server returned: %@, alternate server: %@",errorMessage1,errorMessage2];
        
        [OHAlertView showAlertWithTitle:@"Unable to sync" message:errorMessage dismissButton:@"Ok"];
    }
    
    [self.loadingView removeFromSuperview];
    [self showFinishLoadingValues];
    [self loadData];
}

- (IBAction)onSubmit:(id)sender
{
    [[UIDevice currentDevice] playInputClick];
    
    NSMutableArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@ && submitted == NIL && bibNumber != %@",[CurrentCourse getCurrentCourse].eventId,@"-1"]].mutableCopy;
    if (entries.count == 0)
    {
        if (self.entries.count == 0)
            [OHAlertView showAlertWithTitle:@"" message:@"No times have been entered." dismissButton:@"Ok"];
        else [OHAlertView showAlertWithTitle:@"" message:@"All times have been synced." dismissButton:@"Ok"];
        return;
    }
    
    [[OSTSyncManager shared] syncEntries:entries];
    
    [self showLoadingScreen];
    [self showLoadingValues];
}

- (IBAction)onSubmit_old:(id)sender
{
    [[UIDevice currentDevice] playInputClick];
    
    NSMutableArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"combinedCourseId == %@ && submitted == NIL && bibNumber != %@",[CurrentCourse getCurrentCourse].eventId,@"-1"]].mutableCopy;
    if (entries.count == 0)
    {
        if (self.entries.count == 0)
            [OHAlertView showAlertWithTitle:@"" message:@"No times have been entered." dismissButton:@"Ok"];
        else [OHAlertView showAlertWithTitle:@"" message:@"All times have been synced." dismissButton:@"Ok"];
        return;
    }
    
    [self showLoadingScreen];
    [self showLoadingValues];
    
    __weak OSTReviewSubmitViewController * weakSelf = self;
    
    [[AppDelegate getInstance].getNetworkManager autoLoginWithCompletionBlock:^(id object) {
        [weakSelf submitEntries:entries useAlternateServer:NO completionBlock:^(id object) {
            [weakSelf showFinishLoadingValues];
            [weakSelf loadData];
        } errorBlock:^(NSError *error) {
            [weakSelf.loadingView removeFromSuperview];
            [weakSelf showFinishLoadingValues];
            [OHAlertView showAlertWithTitle:@"Unable to sync" message:[NSString stringWithFormat:@"%@",[error errorsFromDictionary]] dismissButton:@"Ok"];
            [weakSelf loadData];
        }];
    } errorBlock:^(NSError *error) {
    
        NSString * errorMessage1 = nil;
        if (error.code == -1009)
        {
            errorMessage1 = @"The device is not connected to the internet or the alternate server";
            //[weakSelf.loadingView removeFromSuperview];
            //[weakSelf showFinishLoadingValues];
            
            //[OHAlertView showAlertWithTitle:@"Unable to sync" message:errorMessage1 dismissButton:@"Ok"];
            //[weakSelf loadData];
            //return;
        }
        else
        {
            errorMessage1 = [NSString stringWithFormat:@"Error: %@",[error errorsFromDictionary]];
        }
        
        [weakSelf submitEntries:entries useAlternateServer:YES completionBlock:^(id object) {
            [weakSelf showFinishLoadingValues];
            [weakSelf loadData];
        } errorBlock:^(NSError *error) {
            [weakSelf.loadingView removeFromSuperview];
            [weakSelf showFinishLoadingValues];
            NSString * errorMessage2 = nil;
            
            errorMessage2 = [NSString stringWithFormat:@"Error: %@",[error errorsFromDictionary]];
            
            NSString * errorMessage = [NSString stringWithFormat:@"Primary server returned: %@, alternate server: %@",errorMessage1,errorMessage2];
            
            [OHAlertView showAlertWithTitle:@"Unable to sync" message:errorMessage dismissButton:@"Ok"];
            [weakSelf loadData];
        }];
    }];
}

- (void) submitEntries:(NSMutableArray*) entries useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSArray * subEntries = nil;
    
    long entriesCount = entries.count;
    
    if (entriesCount > 300)
    {
        subEntries = [entries subarrayWithRange:NSMakeRange(0, 300)];
        self.progressBar.progress = 300.0/entriesCount;
    }
    else
    {
        subEntries = [entries subarrayWithRange:NSMakeRange(0, entriesCount)];
        self.progressBar.progress = 1;
    }
    
    if (subEntries.count == 0)
    {
        onCompletion(nil);
        return;
    }
    
    __weak OSTReviewSubmitViewController * weakSelf = self;
    //[[AppDelegate getInstance].getNetworkManager submitGroupedEntries:subEntries useAlternateServer:alternateServer completionBlock:^(id object) {
    [[AppDelegate getInstance].getNetworkManager submitEventGroupEntries:subEntries useAlternateServer:alternateServer completionBlock:^(id object) {
    
        for (EntryModel * entry in subEntries)
        {
            entry.submitted = @(YES);
            [entries removeObject:entry];
        }
        
        [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
        
        [weakSelf submitEntries:entries useAlternateServer:alternateServer completionBlock:onCompletion errorBlock:onError];
        
    } errorBlock:^(NSError *error) {
        onError(error);
    }];
}

#pragma mark - UITableviewDelegate

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
{
    return [self.entries[section] count];
}

- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    OSTReviewSectionHeader * sectionHeader = [OSTReviewSectionHeader instanceFromNib];
    
    sectionHeader.lblTitle.text = [NSString stringWithFormat:@"%@ Entries:", self.splitTitles[section]];
    
    return sectionHeader;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    OSTReviewTableViewCell * cell = [tableView dequeueReusableCellWithIdentifier:@"OSTReviewTableViewCell" forIndexPath:indexPath];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    [cell configureWithEntry:self.entries[indexPath.section][indexPath.row]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(nonnull NSIndexPath *)indexPath
{
    if ([[OSTSyncManager shared] isSyncingEntry:self.entries[indexPath.section][indexPath.row]]) {
        [OHAlertView showAlertWithTitle:@"Unable to edit time" message:@"Time is been synced." dismissButton:@"Ok"];
        return;
    }
    
    if ([[self.entries[indexPath.section][indexPath.row] submitted] boolValue])
    {
        __weak OSTReviewSubmitViewController * weakSelf = self;
        [OHAlertView showAlertWithTitle:@"" message:@"Time has already been synced. Create a replacement time?" cancelButton:@"No" otherButtons:@[@"Yes"] buttonHandler:^(OHAlertView *alert, NSInteger buttonIndex)
         {
             if (buttonIndex == 1)
             {
                 OSTEditEntryViewController * editVC = [[OSTEditEntryViewController alloc] initWithNibName:nil bundle:nil];
                 editVC.creatingNew = YES;
                 [weakSelf presentViewController:editVC animated:YES completion:nil];
                 [editVC configureWithEntry:weakSelf.entries[indexPath.section][indexPath.row]];
             }
         }];
        return;
    }
    
    OSTEditEntryViewController * editVC = [[OSTEditEntryViewController alloc] initWithNibName:nil bundle:nil];
    [self presentViewController:editVC animated:YES completion:nil];
    [editVC configureWithEntry:self.entries[indexPath.section][indexPath.row]];
}

@end
