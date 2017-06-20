//
//  OSTReviewTableViewCell.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/19/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTReviewTableViewCell.h"

@implementation OSTReviewTableViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (void) configureWithEntry:(EntryModel*) entry
{
    self.lblTime.text = entry.displayTime;
    self.lblName.text = entry.fullName;
    self.lblNumber.text = [NSString stringWithFormat:@"#%@",entry.bibNumber];
    self.lblInOrOut.text = entry.bitKey;
}

@end
