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

@interface OSTCrossCheckViewController ()

@property (strong, nonatomic) NSArray* efforts;

@end

@implementation OSTCrossCheckViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.efforts = [EffortModel MR_findAllSortedBy:@"bibNumber" ascending:YES];
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

- (IBAction)onMenu:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}

- (IBAction)onBulkSelect:(id)sender
{
    
}

@end
