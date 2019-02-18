//
//  OSTCrossCheckViewController.m
//  OST Tracker
//
//  Created by Luciano Castro on 10/20/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTCrossCheckViewController.h"
#import "OSTCrossCheckCell.h"
#import "EffortModel.h"
#import "CrossCheckEntriesModel.h"
#import "UIView+Additions.h"
#import "CurrentCourse.h"
#import "OSTCrossCheckHeader.h"
#import "OSTNetworkManager+Entries.h"
#import "EntryModel.h"
#import "OSTCheckmarkView.h"

typedef enum {
    
    OSTCrossCheckFilterRecorded = 1,
    OSTCrossCheckFilterDroppedHere = 2,
    OSTCrossCheckFilterExpected = 3,
    OSTCrossCheckFilterNotExpected = 4,
    OSTCrossCheckFilterAll = 0
    
}OSTCrossCheckFilter;

@interface OSTCrossCheckViewController ()
@property (weak, nonatomic) IBOutlet UIView *popupOverlay;

@property (weak, nonatomic) IBOutlet UIView *popupView;
@property (weak, nonatomic) IBOutlet UIButton *btnReviewEntries;
@property (strong, atomic) NSArray* efforts;
@property (weak, nonatomic) IBOutlet UILabel *lblPupupEntryName;
@property (weak, nonatomic) IBOutlet UIView *bulkSelectMenuView;
@property (weak, nonatomic) IBOutlet UIButton *btnBulkSelect;
@property (weak, nonatomic) IBOutlet UISwitch *swchPopupExpected;
@property (weak, nonatomic) IBOutlet UIView *popupCrossCheckContainer;
@property (weak, nonatomic) IBOutlet UIView *popupSegmentedView;
@property (weak, nonatomic) IBOutlet UICollectionView *crossCheckCollection;
@property (strong, nonatomic) EffortModel * popupEffort;
@property (weak, nonatomic) IBOutlet UILabel *popupCellStatusLabel;
@property (weak, nonatomic) IBOutlet UIImageView *popupAidIcon;
@property (weak, nonatomic) IBOutlet UILabel *popupBibNumber;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UIImageView *popupDroppedHereIcon;
@property (strong, nonatomic) CrossCheckEntriesModel * popupCrossCheckModel;
@property (assign, nonatomic) BOOL bulkSelect;
@property (nonatomic, strong) NSString * splitName;
@property (weak, nonatomic) IBOutlet UIButton *btnRightMenu;
@property (weak, nonatomic) IBOutlet UIView *footerView;
@property (weak, nonatomic) IBOutlet OSTCheckmarkView *selectedFilterView;
@property (nonatomic,assign) OSTCrossCheckFilter filter;
@property (nonatomic,strong) NSArray *currentEfforts;

@end

@implementation OSTCrossCheckViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.popupView.top = self.view.bottom;
    
    [self adjustCrossCheckCollectionBottomInset];
    
    self.filter = (OSTCrossCheckFilter)self.selectedFilterView.tag;
    self.selectedFilterView.selected = YES;
    
    self.popupCrossCheckContainer.layer.cornerRadius = 6;
    NSString *currentCourseSplitName = [CurrentCourse getCurrentCourse].splitName;
    self.splitName = currentCourseSplitName;
    for (NSDictionary * entrie in [CurrentCourse getCurrentCourse].dataEntryGroups)
    {
        if ([entrie[@"entries"] count] == 1)
            continue;
        if ([entrie[@"title"] isEqualToString:currentCourseSplitName])
        {
            if (([entrie[@"entries"][0][@"subSplitKind"] isEqualToString:@"in"] && [entrie[@"entries"][1][@"subSplitKind"] isEqualToString:@"in"])||
                ([entrie[@"entries"][0][@"subSplitKind"] isEqualToString:@"out"] && [entrie[@"entries"][1][@"subSplitKind"] isEqualToString:@"out"]))
            {
                self.splitName = entrie[@"entries"][0][@"splitName"];
            }
        }
    }
    
    if (IS_IPHONE_X)
    {
        self.lblTitle.numberOfLines = 1;
        self.lblTitle.bottom = self.lblTitle.bottom + 7;
        self.btnRightMenu.bottom = self.btnRightMenu.bottom + 7;
        self.btnBulkSelect.bottom = self.btnBulkSelect.bottom + 7;
    }
    
    [self reloadData];
}

- (void)fetchNotExpected
{
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [[AppDelegate getInstance].getNetworkManager fetchNotExpected:[CurrentCourse getCurrentCourse].eventGroupId splitName:self.splitName useAlternateServer:NO completionBlock:^(id  _Nullable object) {
        
        if ([object isKindOfClass:[NSDictionary class]])
        {
            id bibNumbers = [object valueForKeyPath:@"data.bib_numbers"];
            if ([bibNumbers isKindOfClass:[NSArray class]])
            {
                [self bulkNotExpectedBibNumbers:bibNumbers];
                [self.crossCheckCollection reloadData];
            }
        }
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        
    } errorBlock:^(NSError * _Nullable error) {
        
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        
    }];
}

- (void) reloadData
{
    __block NSMutableArray * entriesThatShouldBeHere = [NSMutableArray new];
    [DejalBezelActivityView activityViewForView:self.view];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.efforts = [EffortModel MR_findAllSortedBy:@"bibNumber" ascending:YES withPredicate:[NSPredicate predicateWithFormat:@"bibNumber != nil"]];
        
        [self fetchNotExpected];
        
        dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            for (EffortModel * effort in self.efforts)
            {
                if ([effort checkIfEffortShouldBeInSplit:[CurrentCourse getCurrentCourse].splitName selectedSplitName:self.splitName])
                {
                    [effort expectedWithSplitName:self.splitName];
                    [entriesThatShouldBeHere addObject:effort];
                }
            }
            
            dispatch_async( dispatch_get_main_queue(), ^{
                self.efforts = entriesThatShouldBeHere;
                [self applyFilter];
                [DejalBezelActivityView removeViewAnimated:YES];
            });
        });
        
    });
}

- (NSArray *)recordedEffortsDroppedHere:(BOOL)droppedHere
{
    NSMutableArray *filteredEfforts = [NSMutableArray new];
    
    for (EffortModel *effort in self.efforts)
    {
        NSArray * entries = [effort entriesForSplitName:self.splitName];
        if (entries.count > 0)
        {
            if (effort.stoppedHere != nil && [effort.stoppedHere boolValue] == YES)
            {
                if (droppedHere)
                {
                    [filteredEfforts addObject:effort];
                }
            }
            else
            {
                if (!droppedHere)
                {
                    [filteredEfforts addObject:effort];
                }
            }
        }
    }
    
    return filteredEfforts;
}

- (NSArray *)nonRecordedEffortsExpected:(BOOL)includeExpected
{
    NSMutableArray *filteredEfforts = [NSMutableArray new];
    
    for (EffortModel *effort in self.efforts)
    {
        NSArray * entries = [effort entriesForSplitName:self.splitName];
        
        if (entries.count == 0)
        {
            BOOL expected = [effort expectedWithSplitName:self.splitName] == nil || [[effort expectedWithSplitName:self.splitName] isEqualToNumber:@(YES)];
            if ((includeExpected && expected) || (!includeExpected && !expected))
            {
                [filteredEfforts addObject:effort];
            }
        }
    }
    
    return filteredEfforts;
}

- (void)applyFilter
{
    switch (self.filter)
    {
        case OSTCrossCheckFilterAll:
            self.currentEfforts = self.efforts;
            break;
            
        case OSTCrossCheckFilterRecorded:
            self.currentEfforts = [self recordedEffortsDroppedHere:NO];
            break;
            
        case OSTCrossCheckFilterDroppedHere:
            self.currentEfforts = [self recordedEffortsDroppedHere:YES];
            break;
            
        case OSTCrossCheckFilterExpected:
            self.currentEfforts = [self nonRecordedEffortsExpected:YES];
            break;
            
        case OSTCrossCheckFilterNotExpected:
            self.currentEfforts = [self nonRecordedEffortsExpected:NO];
            break;
    }
    
    [self.crossCheckCollection reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UICollectionViewDelegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.currentEfforts.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    OSTCrossCheckCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"OSTCrossCheckCell" forIndexPath:indexPath];
    
    cell.splitName = self.splitName;
    [cell configureWithEffort:self.currentEfforts[indexPath.row]];
    
    if (self.bulkSelect)
    {
        if (![cell.lblStatus.text isEqualToString:@"Expected"] &&
            ![cell.lblStatus.text isEqualToString:@"Not Expected"])
        {
            cell.noBulkSelectView.hidden = NO;
        }
        else
        {
            cell.noBulkSelectView.hidden = YES;
        }
    }
    
    if ([self.currentEfforts[indexPath.row] bulkSelected])
    {
        cell.noBulkSelectView.hidden = NO;
    }

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.bulkSelect)
    {
        EffortModel * effort = self.currentEfforts[indexPath.row];
        OSTCrossCheckCell *cell = (OSTCrossCheckCell*)[collectionView cellForItemAtIndexPath:indexPath];
        
        if (![cell.lblStatus.text isEqualToString:@"Expected"] && ![cell.lblStatus.text isEqualToString:@"Not Expected"])
        {
            return;
        }
        
        effort.bulkSelected = !effort.bulkSelected;
        
        [cell configureWithEffort:effort];
        
        return;
    }
    self.popupEffort = self.currentEfforts[indexPath.row];
    self.lblPupupEntryName.text = self.popupEffort.fullName;
    
    OSTCrossCheckCell *cell = (OSTCrossCheckCell*)[collectionView cellForItemAtIndexPath:indexPath];
    
    self.popupAidIcon.hidden = cell.imgAid.hidden;
    self.popupDroppedHereIcon.hidden = cell.imgDroppedHere.hidden;
    
    self.popupCrossCheckContainer.backgroundColor = cell.backgroundColor;
    self.popupBibNumber.textColor = cell.lblBibNumber.textColor;
    self.popupCellStatusLabel.backgroundColor = cell.lblStatus.backgroundColor;
    self.popupBibNumber.text = cell.lblBibNumber.text;
    
    self.popupCellStatusLabel.text = cell.lblStatus.text;
    
    if ([self.popupCellStatusLabel.text isEqualToString:@"Expected"] ||
        [self.popupCellStatusLabel.text isEqualToString:@"Not Expected"])
    {
        self.popupSegmentedView.hidden = NO;
        self.btnReviewEntries.hidden = YES;
        
        self.swchPopupExpected.on = [self.popupCellStatusLabel.text isEqualToString:@"Expected"];
    }
    else
    {
        self.popupSegmentedView.hidden = YES;
        self.btnReviewEntries.hidden = NO;
    }
    [self showPopup];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    UICollectionReusableView *reusableview = nil;
    __weak OSTCrossCheckViewController * weakSelf = self;
    
    if (kind == UICollectionElementKindSectionHeader) {
        OSTCrossCheckHeader *headerView = (OSTCrossCheckHeader*)[collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"OSTCrossCheckHeader" forIndexPath:indexPath];
        
        reusableview = headerView;
        
        headerView.lblStationName.text = [CurrentCourse getCurrentCourse].splitName;
        headerView.segLocation.hidden = YES;
        headerView.lblStationName.hidden = NO;
        
        for (NSDictionary * entrie in [CurrentCourse getCurrentCourse].dataEntryGroups)
        {
            if ([entrie[@"entries"] count] == 1)
                 continue;
    
            if ([entrie[@"title"] isEqualToString:[CurrentCourse getCurrentCourse].splitName])
            {
                if (([entrie[@"entries"][0][@"subSplitKind"] isEqualToString:@"in"] && [entrie[@"entries"][1][@"subSplitKind"] isEqualToString:@"in"])||
                    ([entrie[@"entries"][0][@"subSplitKind"] isEqualToString:@"out"] && [entrie[@"entries"][1][@"subSplitKind"] isEqualToString:@"out"]))
                {
                    headerView.segLocation.hidden = NO;
                    headerView.lblStationName.hidden = YES;
                    [headerView.segLocation setTitle:entrie[@"entries"][0][@"splitName"] forSegmentAtIndex:0];
                    [headerView.segLocation setTitle:entrie[@"entries"][1][@"splitName"] forSegmentAtIndex:1];
                    [headerView setSplitChange:^(NSString *newSplitName) {
                        weakSelf.splitName = newSplitName;
                        for (EffortModel * effort in weakSelf.efforts)
                        {
                            //effort.expected = nil;
                            //effort.entries = nil;
                            [effort clearVariables];
                        }
                        [weakSelf reloadData];
                    }];
                }
                else
                {
                    headerView.segLocation.hidden = YES;
                    headerView.lblStationName.hidden = NO;
                }
            }
        }
        
    }
    
    if (kind == UICollectionElementKindSectionFooter) {
        UICollectionReusableView *footerview = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"OSTCrossCheckFooter" forIndexPath:indexPath];
        
        reusableview = footerview;
    }
    
    return reusableview;
}

- (IBAction)onFilter:(OSTCheckmarkView *)checkmark
{
    if (self.selectedFilterView != nil)
    {
        self.selectedFilterView.selected = NO;
    }
    self.filter = (OSTCrossCheckFilter)checkmark.tag;
    [self applyFilter];
    self.selectedFilterView = checkmark;
}

- (IBAction)changedSwich:(id)sender
{
    
}

- (IBAction)onMenu:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}

- (IBAction)onBulkSelect:(id)sender
{
    for (EffortModel * effort in self.efforts)
    {
        effort.bulkSelected = NO;
    }
    
    if (self.bulkSelect)
    {
        self.bulkSelect = NO;
        self.footerView.height = 82;
        [self.btnBulkSelect setTitle:@"Bulk Select" forState:UIControlStateNormal];
        self.bulkSelectMenuView.hidden = YES;
    }
    else
    {
        self.bulkSelect = YES;
        self.footerView.height = 132;
        [self.btnBulkSelect setTitle:@"Cancel" forState:UIControlStateNormal];
        self.bulkSelectMenuView.hidden = NO;
    }
    
    self.footerView.top = self.view.height - self.footerView.height;
    [self adjustCrossCheckCollectionBottomInset];
    [self.crossCheckCollection reloadData];
}

- (void)adjustCrossCheckCollectionBottomInset
{
    self.crossCheckCollection.contentInset = UIEdgeInsetsMake(0, 0, self.footerView.height, 0);
}

- (IBAction)onClosePopup:(id)sender
{
    if (self.swchPopupExpected.hidden == NO)
    {
        if (self.popupCrossCheckModel)
        {
            if (self.swchPopupExpected.isOn)
            {
                [self.popupCrossCheckModel MR_deleteEntity];
                [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
                [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
                self.popupEffort.expected = @(YES);
            }
        }
        else
        {
            if(!self.swchPopupExpected.isOn)
            {
                CrossCheckEntriesModel * crossCheckEntry = [CrossCheckEntriesModel MR_createEntity];
                crossCheckEntry.bibNumber = [self.popupEffort.bibNumber stringValue];
                crossCheckEntry.splitName = self.splitName;
                crossCheckEntry.courseId = [CurrentCourse getCurrentCourse].eventId;
                
                [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
                [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
                self.popupEffort.expected = @(NO);
            }
        }
    }
    
    [self.crossCheckCollection reloadData];
    
    [self hidePopup];
}

- (void) hidePopup
{
    __weak OSTCrossCheckViewController * weakSelf = self;
    [UIView animateWithDuration:0.25 animations:^{
        weakSelf.popupView.top = self.view.bottom;
        weakSelf.popupOverlay.alpha = 0;
    }];
}
- (IBAction)onBulkExpected:(id)sender
{
    CrossCheckEntriesModel * crossCheckEntry;
    for (EffortModel * effort in self.efforts)
    {
        if (effort.bulkSelected)
        {
            crossCheckEntry = [CrossCheckEntriesModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[effort.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,self.splitName]];
            if (crossCheckEntry)
            {
                [crossCheckEntry MR_deleteEntity];
                
                [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
                [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
            }
            effort.expected = @(YES);
        }
    }
    
    [self applyFilter];
    [self onBulkSelect:nil];
}

- (void)bulkNotExpectedBibNumbers:(NSArray *)bibNumbers
{
    NSMutableArray *notExpected = [NSMutableArray new];
    for (EffortModel *effort in self.efforts)
    {
        //Recorded/Dropped efforts should not update their current state based on the given bib numbers
        if ([effort entriesForSplitName:self.splitName].count > 0) {
            continue;
        }
        
        if ([bibNumbers containsObject:effort.bibNumber])
        {
            [notExpected addObject:effort];
        }
        else
        {
            CrossCheckEntriesModel *crossCheckEntry = [CrossCheckEntriesModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[effort.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,self.splitName]];
            if (crossCheckEntry)
            {
                [crossCheckEntry MR_deleteEntity];
                
                [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
                [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
                effort.expected = @(YES);
            }
        }
    }
    [self bulkNotExpectedEfforts:notExpected];
}

- (void)bulkNotExpectedEfforts:(NSArray *)efforts
{
    CrossCheckEntriesModel * crossCheckEntry;
    for (EffortModel * effort in efforts)
    {
        crossCheckEntry = [CrossCheckEntriesModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[effort.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,self.splitName]];
        if (!crossCheckEntry)
        {
            crossCheckEntry = [CrossCheckEntriesModel MR_createEntity];
            crossCheckEntry.bibNumber = [effort.bibNumber stringValue];
            crossCheckEntry.splitName = self.splitName;
            crossCheckEntry.courseId = [CurrentCourse getCurrentCourse].eventId;
            
            [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
            [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
            effort.expected = @(NO);
        }
    }
}

- (IBAction)onBulkNotExpected:(id)sender
{
    NSMutableArray *notExpected = [NSMutableArray new];
    for (EffortModel * effort in self.efforts)
    {
        if (effort.bulkSelected)
        {
            [notExpected addObject:effort];
        }
    }
    [self bulkNotExpectedEfforts:notExpected];
    [self applyFilter];
    [self onBulkSelect:nil];
}

- (IBAction)onReviewEntries:(id)sender
{
    [[AppDelegate getInstance] showReview];
}

- (void) showPopup
{
    self.popupCrossCheckModel = [CrossCheckEntriesModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[self.popupEffort.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,self.splitName]];
    __weak OSTCrossCheckViewController * weakSelf = self;
    [UIView animateWithDuration:0.25 animations:^{
        weakSelf.popupView.top = self.view.bottom - self.popupView.height;
        weakSelf.popupOverlay.alpha = 0.3;
    }];
}

@end
