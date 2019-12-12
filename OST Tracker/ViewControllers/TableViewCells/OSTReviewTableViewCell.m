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
    if (self.lblName.text.length == 0)
    {
        self.lblName.text = @"Bib not found";
    }
    if (![entry.bibNumber isEqualToString:@"-1"])
        self.lblNumber.text = [NSString stringWithFormat:@"#%@",entry.bibNumber];
    else self.lblNumber.text = @"";
    self.lblInOrOut.text = [entry.bitKey capitalizedString];
    
    UIFont *currentFont = self.lblName.font;
    UIFont *newFont = [UIFont systemFontOfSize:currentFont.pointSize];
    self.lblName.font = newFont;
    
    if (entry.submitted.boolValue)
    {
        self.lblTime.textColor = [UIColor colorWithRed:28.0/255 green:186.0/255 blue:51.0/255 alpha:1];
        self.lblName.textColor = [UIColor colorWithRed:28.0/255 green:186.0/255 blue:51.0/255 alpha:1];
        self.lblNumber.textColor = [UIColor colorWithRed:28.0/255 green:186.0/255 blue:51.0/255 alpha:1];
        self.lblInOrOut.textColor = [UIColor colorWithRed:28.0/255 green:186.0/255 blue:51.0/255 alpha:1];
        
        self.imgPacer.image = [UIImage imageNamed:@"Pacer Symbol Green"];
        self.imgStopped.image = [UIImage imageNamed:@"Green Hand"];
        
        if ([self.lblName.text isEqualToString:@"Bib not found"])
        {
            UIFont *currentFont = self.lblName.font;
            UIFont *newFont = [UIFont boldSystemFontOfSize:currentFont.pointSize];
            self.lblName.font = newFont;
        }
    }
    else
    {
        if ([self.lblName.text isEqualToString:@"Bib not found"])
        {
            self.lblName.textColor = [UIColor redColor];
            
            UIFont *currentFont = self.lblName.font;
            UIFont *newFont = [UIFont boldSystemFontOfSize:currentFont.pointSize];
            self.lblName.font = newFont;
        }
        else
        {
            self.lblName.textColor = [UIColor blackColor];
        }
        
        self.lblTime.textColor = [UIColor blackColor];
        self.lblNumber.textColor = [UIColor blackColor];
        self.lblInOrOut.textColor = [UIColor blackColor];
        
        self.imgPacer.image = [UIImage imageNamed:@"Pacer Symbol Blue"];
        self.imgStopped.image = [UIImage imageNamed:@"Red Hand"];
    }
    
    self.imgStopped.hidden = !entry.stoppedHere.boolValue;
    self.imgPacer.hidden = !entry.withPacer.boolValue;
}

@end
