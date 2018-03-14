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
@property (weak, nonatomic) IBOutlet UIImageView *popupDroppedHereIcon;
@property (strong, nonatomic) CrossCheckEntriesModel * popupCrossCheckModel;
@property (assign, nonatomic) BOOL bulkSelect;
@property (nonatomic, strong) NSString * splitName;

@end

@implementation OSTCrossCheckViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.popupView.top = self.view.bottom;
    
    self.popupCrossCheckContainer.layer.cornerRadius = 6;
    self.splitName = [CurrentCourse getCurrentCourse].splitName;
    for (NSDictionary * entrie in [CurrentCourse getCurrentCourse].combinedSplitAttributes)
    {
        if ([entrie[@"entries"] count] == 1)
            break;
        if ([entrie[@"title"] isEqualToString:[CurrentCourse getCurrentCourse].splitName])
        {
            if (([entrie[@"entries"][0][@"subSplitKind"] isEqualToString:@"in"] && [entrie[@"entries"][1][@"subSplitKind"] isEqualToString:@"in"])||
                ([entrie[@"entries"][0][@"subSplitKind"] isEqualToString:@"out"] && [entrie[@"entries"][1][@"subSplitKind"] isEqualToString:@"out"]))
            {
                self.splitName = entrie[@"entries"][0][@"displaySplitName"];
            }
        }
    }
    
    [self reloadData];
}

- (void) reloadData
{
    self.efforts = [EffortModel MR_findAllSortedBy:@"bibNumber" ascending:YES];
    __block NSMutableArray * entriesThatShouldBeHere = [NSMutableArray new];
    [DejalBezelActivityView activityViewForView:self.view];
    dispatch_async( dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        for (EffortModel * effort in self.efforts)
        {
            if ([effort checkIfEffortShouldBeInSplit:[CurrentCourse getCurrentCourse].splitName])
            {
                effort.expected;
                [entriesThatShouldBeHere addObject:effort];
            }
        }
    
        dispatch_async( dispatch_get_main_queue(), ^{
            self.efforts = entriesThatShouldBeHere;
            [self.crossCheckCollection reloadData];
            [DejalBezelActivityView removeViewAnimated:YES];
        });
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UICollectionViewDelegate

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.efforts.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    OSTCrossCheckCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"OSTCrossCheckCell" forIndexPath:indexPath];
    
    cell.splitName = self.splitName;
    [cell configureWithEffort:self.efforts[indexPath.row]];
    
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
    
    if ([self.efforts[indexPath.row] bulkSelected])
    {
        cell.noBulkSelectView.hidden = NO;
    }

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.bulkSelect)
    {
        EffortModel * effort = self.efforts[indexPath.row];
        OSTCrossCheckCell *cell = (OSTCrossCheckCell*)[collectionView cellForItemAtIndexPath:indexPath];
        
        if (![cell.lblStatus.text isEqualToString:@"Expected"] && ![cell.lblStatus.text isEqualToString:@"Not Expected"])
        {
            return;
        }
        
        effort.bulkSelected = !effort.bulkSelected;
        
        [cell configureWithEffort:effort];
        
        return;
    }
    self.popupEffort = self.efforts[indexPath.row];
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
        
        for (NSDictionary * entrie in [CurrentCourse getCurrentCourse].combinedSplitAttributes)
        {
            if ([entrie[@"entries"] count] == 1)
                 break;
            if ([entrie[@"title"] isEqualToString:[CurrentCourse getCurrentCourse].splitName])
            {
                if (([entrie[@"entries"][0][@"subSplitKind"] isEqualToString:@"in"] && [entrie[@"entries"][1][@"subSplitKind"] isEqualToString:@"in"])||
                    ([entrie[@"entries"][0][@"subSplitKind"] isEqualToString:@"out"] && [entrie[@"entries"][1][@"subSplitKind"] isEqualToString:@"out"]))
                {
                    headerView.segLocation.hidden = NO;
                    headerView.lblStationName.hidden = YES;
                    [headerView.segLocation setTitle:entrie[@"entries"][0][@"displaySplitName"] forSegmentAtIndex:0];
                    [headerView.segLocation setTitle:entrie[@"entries"][1][@"displaySplitName"] forSegmentAtIndex:1];
                    self.splitName = entrie[@"entries"][0][@"displaySplitName"];
                    [headerView setSplitChange:^(NSString *newSplitName) {
                        weakSelf.splitName = newSplitName;
                        for (EffortModel * effort in weakSelf.efforts)
                        {
                            //effort.expected = nil;
                            //effort.entries = nil;
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
        [self.btnBulkSelect setTitle:@"Bulk Select" forState:UIControlStateNormal];
        self.bulkSelectMenuView.hidden = YES;
    }
    else
    {
        self.bulkSelect = YES;
        [self.btnBulkSelect setTitle:@"Cancel" forState:UIControlStateNormal];
        self.bulkSelectMenuView.hidden = NO;
    }
    
    [self.crossCheckCollection reloadData];
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
    
    [self onBulkSelect:nil];
}

- (IBAction)onBulkNotExpected:(id)sender
{
    CrossCheckEntriesModel * crossCheckEntry;
    for (EffortModel * effort in self.efforts)
    {
        if (effort.bulkSelected)
        {
            crossCheckEntry = [CrossCheckEntriesModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[effort.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,self.splitName]];
            if (!crossCheckEntry)
            {
                crossCheckEntry = [CrossCheckEntriesModel MR_createEntity];
                crossCheckEntry.bibNumber = [effort.bibNumber stringValue];
                crossCheckEntry.splitName = [CurrentCourse getCurrentCourse].splitName;
                crossCheckEntry.courseId = [CurrentCourse getCurrentCourse].eventId;
                
                [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
                [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
                effort.expected = @(NO);
            }
        }
    }
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
