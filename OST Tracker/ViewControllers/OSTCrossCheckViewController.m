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

@interface OSTCrossCheckViewController ()
@property (weak, nonatomic) IBOutlet UIView *popupOverlay;

@property (weak, nonatomic) IBOutlet UIView *popupView;
@property (weak, nonatomic) IBOutlet UIButton *btnReviewEntries;
@property (strong, nonatomic) NSArray* efforts;
@property (weak, nonatomic) IBOutlet UILabel *lblPupupEntryName;
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

@end

@implementation OSTCrossCheckViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.popupView.top = self.view.bottom;
    
    self.popupCrossCheckContainer.layer.cornerRadius = 6;
    
    [self reloadData];
}

- (void) reloadData
{
    self.efforts = [EffortModel MR_findAllSortedBy:@"bibNumber" ascending:YES];
    [self.crossCheckCollection reloadData];
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
    
    [cell configureWithEffort:self.efforts[indexPath.row]];
    
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
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
    
    if (kind == UICollectionElementKindSectionHeader) {
        UICollectionReusableView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"OSTCrossCheckHeader" forIndexPath:indexPath];
        
        reusableview = headerView;
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
            }
        }
        else
        {
            if(!self.swchPopupExpected.isOn)
            {
                CrossCheckEntriesModel * crossCheckEntry = [CrossCheckEntriesModel MR_createEntity];
                crossCheckEntry.bibNumber = [self.popupEffort.bibNumber stringValue];
                crossCheckEntry.splitName = [CurrentCourse getCurrentCourse].splitName;
                crossCheckEntry.courseId = [CurrentCourse getCurrentCourse].eventId;
                
                [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
                [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
            }
        }
    }
    
    [self reloadData];
    
    [self hidePopup];
}

- (void) hidePopup
{
    __weak OSTCrossCheckViewController * weakSelf = self;
    [UIView animateWithDuration:0.5 animations:^{
        weakSelf.popupView.top = self.view.bottom;
        weakSelf.popupOverlay.alpha = 0;
    }];
}

- (void) showPopup
{
    self.popupCrossCheckModel = [CrossCheckEntriesModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[self.popupEffort.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,[CurrentCourse getCurrentCourse].splitName]];
    __weak OSTCrossCheckViewController * weakSelf = self;
    [UIView animateWithDuration:0.5 animations:^{
        weakSelf.popupView.top = self.view.bottom - self.popupView.height;
        weakSelf.popupOverlay.alpha = 0.3;
    }];
}

@end
