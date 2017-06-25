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
@property (weak, nonatomic) IBOutlet UITableView *tableView;
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
    self.txtSortBy.selectedRow = 1;
    
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
    
    if (self.txtSortBy.selectedRow == 0)
    {
        sortKey = @"fullName";
    }
    else if (self.txtSortBy.selectedRow == 1)
    {
        sortKey = @"entryTime";
    }
    else if (self.txtSortBy.selectedRow == 2)
    {
        sortKey = @"timeEntered";
    }
    else if (self.txtSortBy.selectedRow == 3)
    {
        sortKey = @"bibNumberDecimal";
    }
    
    for (NSString * title in self.splitTitles)
    {
        splitEntries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"courseId == %@ && splitName == %@",[CurrentCourse getCurrentCourse].eventId,title]].mutableCopy;
        [splitEntries sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:sortKey ascending:YES]]];
        [self.entries addObject:splitEntries];
    }
    
    
    self.lblTitle.text = [CurrentCourse getCurrentCourse].eventName;
    
    [self.tableView reloadData];
}

- (IBAction)onRightMenu:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC showRightMenu:YES];
}

- (IBAction)onSubmit:(id)sender
{
    NSMutableArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"courseId == %@ && submitted == NIL",[CurrentCourse getCurrentCourse].eventId]].mutableCopy;
    if (entries.count == 0)
    {
        [OHAlertView showAlertWithTitle:@"Error" message:@"Nothing to send" dismissButton:@"Ok"];
        return;
    }
    
    [DejalBezelActivityView activityViewForView:self.view];
    [[AppDelegate getInstance].getNetworkManager autoLoginWithCompletionBlock:^(id object) {
        [self submitEntries:entries completionBlock:^(id object) {
            [DejalBezelActivityView removeViewAnimated:YES];
            [OHAlertView showAlertWithTitle:nil message:@"Submitted" dismissButton:@"Ok"];
            [self loadData];
        } errorBlock:^(NSError *error) {
            [DejalBezelActivityView removeViewAnimated:YES];
            [OHAlertView showAlertWithTitle:@"Unable to sync" message:[NSString stringWithFormat:@"Please try again later when you have a data or wi-fi connection. Error: %@",[error errorsFromDictionary]] dismissButton:@"Ok"];
            [self loadData];
        }];
    } errorBlock:^(NSError *error) {
        [DejalBezelActivityView removeViewAnimated:YES];
        [OHAlertView showAlertWithTitle:@"Error" message:@"Can't submit, try again later" dismissButton:@"Ok"];
        [self loadData];
    }];
}

- (void) submitEntries:(NSMutableArray*) entries completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSArray * subEntries = nil;
    
    long entriesCount = entries.count;
    
    if (entriesCount > 300)
    {
        subEntries = [entries subarrayWithRange:NSMakeRange(0, 300)];
    }
    else
    {
        subEntries = [entries subarrayWithRange:NSMakeRange(0, entriesCount)];
    }
    
    if (subEntries.count == 0)
    {
        onCompletion(nil);
        return;
    }
    
    [[AppDelegate getInstance].getNetworkManager submitEntries:subEntries completionBlock:^(id object) {
    
        for (EntryModel * entry in subEntries)
        {
            entry.submitted = @(YES);
            [entries removeObject:entry];
        }
        
        [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
        [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
        
        [self submitEntries:entries completionBlock:onCompletion errorBlock:onError];
        
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
