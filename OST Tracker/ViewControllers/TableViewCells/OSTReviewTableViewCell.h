//
//  OSTReviewTableViewCell.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/19/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "EntryModel.h"

@interface OSTReviewTableViewCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *lblNumber;
@property (weak, nonatomic) IBOutlet UILabel *lblName;
@property (weak, nonatomic) IBOutlet UILabel *lblInOrOut;
@property (weak, nonatomic) IBOutlet UILabel *lblTime;

- (void) configureWithEntry:(EntryModel*) entry;

@end
