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

@interface OSTReviewSubmitViewController ()
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblSyncing;
@property (strong, nonatomic) IBOutlet UIView *loadingView;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (weak, nonatomic) IBOutlet UILabel *lblYourDataIsSynced;
@property (weak, nonatomic) IBOutlet UIImageView *imgCheckMark;
@property (weak, nonatomic) IBOutlet UILabel *lblSuccess;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (weak, nonatomic) IBOutlet UIProgressView *progressBar;
@property (weak, nonatomic) IBOutlet UIButton *btnReturnToLiveEntry;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtSortBy;
@property (strong, nonatomic) NSMutableArray * entries;
@property (strong, nonatomic) NSArray * splitTitles;

@end

@implementation OSTReviewSubmitViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    [self.tableView registerNib: [UINib nibWithNibName:@"OSTReviewTableViewCell" bundle:nil] forCellReuseIdentifier:@"OSTReviewTableViewCell"];
    
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
        self.txtSortBy.selectedRow = 3;
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
}

- (void) onDoneSelectedSortBy:(id) sender
{
    [[NSUserDefaults standardUserDefaults] setObject:@(self.txtSortBy.selectedRow+1) forKey:@"reviewScreenPicklistValue"];
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
}

- (void) loadData
{
    self.entries = [NSMutableArray new];
    NSArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"courseId == %@",[CurrentCourse getCurrentCourse].eventId]];
    
    NSMutableSet * set = [NSMutableSet new];
    
    for (EntryModel * entry in entries)
    {
        [set addObject:entry.splitName];
    }
    
    self.splitTitles = set.allObjects;
    
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
    
    for (NSString * title in self.splitTitles)
    {
        splitEntries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"courseId == %@ && splitName == %@",[CurrentCourse getCurrentCourse].eventId,title]].mutableCopy;
        [splitEntries sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:sortKey ascending:ascending]]];
        [self.entries addObject:splitEntries];
    }
    
    
    self.lblTitle.text = [CurrentCourse getCurrentCourse].eventName;
    
    [self.tableView reloadData];
}

- (void) showLoadingScreen
{
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
    self.btnReturnToLiveEntry.hidden = YES;
    
    [self.activityIndicator startAnimating];
    self.lblSyncing.hidden = NO;
    self.progressBar.hidden = NO;
}

- (void) showFinishLoadingValues
{
    self.imgCheckMark.hidden = NO;
    self.lblSuccess.hidden = NO;
    self.lblYourDataIsSynced.hidden = NO;
    self.btnReturnToLiveEntry.hidden = NO;
    
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

- (IBAction)onSubmit:(id)sender
{
    NSMutableArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"courseId == %@ && submitted == NIL && bibNumber != %@",[CurrentCourse getCurrentCourse].eventId,@"-1"]].mutableCopy;
    if (entries.count == 0)
    {
        [OHAlertView showAlertWithTitle:@"Error" message:@"Nothing to send" dismissButton:@"Ok"];
        return;
    }
    
    [self showLoadingScreen];
    [self showLoadingValues];
    
    __weak OSTReviewSubmitViewController * weakSelf = self;
    
    [[AppDelegate getInstance].getNetworkManager autoLoginWithCompletionBlock:^(id object) {
        [weakSelf submitEntries:entries completionBlock:^(id object) {
            [weakSelf showFinishLoadingValues];
            [weakSelf loadData];
        } errorBlock:^(NSError *error) {
            [weakSelf.loadingView removeFromSuperview];
            [weakSelf showFinishLoadingValues];
            [OHAlertView showAlertWithTitle:@"Unable to sync" message:[NSString stringWithFormat:@"%@",[error errorsFromDictionary]] dismissButton:@"Ok"];
            [weakSelf loadData];
        }];
    } errorBlock:^(NSError *error) {
    
        NSString * errorMessage = nil;
        if (error.code == -1009)
        {
            errorMessage = @"The device is not connected to the internet.";
        }
        else
        {
            errorMessage = [NSString stringWithFormat:@"Error: %@",[error errorsFromDictionary]];
        }
        
        [weakSelf.loadingView removeFromSuperview];
        [weakSelf showFinishLoadingValues];
        [OHAlertView showAlertWithTitle:@"Unable to sync" message:errorMessage dismissButton:@"Ok"];
        [weakSelf loadData];
    }];
}

- (void) submitEntries:(NSMutableArray*) entries completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
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
    [[AppDelegate getInstance].getNetworkManager submitEntries:subEntries completionBlock:^(id object) {
    
        for (EntryModel * entry in subEntries)
        {
            entry.submitted = @(YES);
            [entries removeObject:entry];
        }
        
        [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
        
        [weakSelf submitEntries:entries completionBlock:onCompletion errorBlock:onError];
        
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
    if ([[self.entries[indexPath.section][indexPath.row] submitted] boolValue])
    {
        return;
    }
    
    OSTEditEntryViewController * editVC = [[OSTEditEntryViewController alloc] initWithNibName:nil bundle:nil];
    [self presentViewController:editVC animated:YES completion:nil];
    [editVC configureWithEntry:self.entries[indexPath.section][indexPath.row]];
}

@end
