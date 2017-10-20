//
//  OSTCrossCheckCell.h
//  OST Tracker
//
//  Created by Luciano Castro on 10/20/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "EffortModel.h"

@interface OSTCrossCheckCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet UILabel *lblStatus;
@property (weak, nonatomic) IBOutlet UIImageView *imgAid;
@property (weak, nonatomic) IBOutlet UIImageView *imgDroppedHere;
@property (weak, nonatomic) IBOutlet UILabel *lblBibNumber;

- (void) configureWithEffort:(EffortModel*)effort;

@end
