//
//  OSTCrossCheckCell.m
//  OST Tracker
//
//  Created by Luciano Castro on 10/20/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTCrossCheckCell.h"
#import "CurrentCourse.h"
#import "EntryModel.h"
#import "CrossCheckEntriesModel.h"

@implementation OSTCrossCheckCell

- (instancetype)initWithCoder:(NSCoder *)decoder
{
    self = [super initWithCoder:decoder];
    if (!self) {
        return nil;
    }
    
    self.layer.cornerRadius = 6;
    
    return self;
}

- (void) configureWithEffort:(EffortModel*)effort
{
    self.lblBibNumber.text = [NSString stringWithFormat:@"%@",effort.bibNumber];
    
    NSArray * entries = [EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[effort.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,[CurrentCourse getCurrentCourse].splitName]];
    
    if (entries.count == 0)
    {
        NSArray * crossCheckEntries = [CrossCheckEntriesModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber LIKE[c] %@ && courseId LIKE[c] %@ && splitName LIKE[c] %@",[effort.bibNumber stringValue],[CurrentCourse getCurrentCourse].eventId,[CurrentCourse getCurrentCourse].splitName]];
        
        if (crossCheckEntries.count != 0)
        {
            [self setAsNotExpected];
        }
        else
        {
            [self setAsExpected];
        }
    }
    else
    {
        [self setAsRecorded];
        for (EntryModel * entry in entries)
        {
            if ([entry.stoppedHere isEqualToString:@"true"])
            {
                [self setAsDroppedHere];
                break;
            }
            else if ([entry.withPacer isEqualToString:@"true"])
            {
                [self setAsWithAid];
                break;
            }
        }
    }
}

- (void) setAsExpected
{
    self.imgAid.hidden = YES;
    self.imgDroppedHere.hidden = YES;
    
    self.backgroundColor = [UIColor colorWithRed:51.0/255 green:156.0/255 blue:211.0/255 alpha:1];
    self.lblBibNumber.textColor = [UIColor whiteColor];
    self.lblStatus.backgroundColor = [UIColor colorWithRed:48.0/255 green:131.0/255 blue:175.0/255 alpha:1];
    
    self.lblStatus.text = @"Expected";
}

- (void) setAsDroppedHere
{
    self.imgAid.hidden = YES;
    self.imgDroppedHere.hidden = NO;
    
    self.backgroundColor = [UIColor whiteColor];
    self.lblStatus.backgroundColor = [UIColor redColor];
    self.lblBibNumber.textColor = [UIColor redColor];
    
    self.lblStatus.text = @"Dropped Here";
}

- (void) setAsWithAid
{
    self.imgAid.hidden = NO;
    self.imgDroppedHere.hidden = YES;
    
    self.backgroundColor = [UIColor whiteColor];
    self.lblBibNumber.textColor = [UIColor colorWithRed:163.0/255 green:163.0/255 blue:163.0/255 alpha:1];
    self.lblStatus.backgroundColor = [UIColor colorWithRed:163.0/255 green:163.0/255 blue:163.0/255 alpha:1];
    
    self.lblStatus.text = @"In Aid";
}

- (void) setAsNotExpected
{
    self.imgAid.hidden = YES;
    self.imgDroppedHere.hidden = YES;
    
    self.backgroundColor = [UIColor colorWithRed:68.0/255 green:67.0/255 blue:61.0/255 alpha:1];
    self.lblBibNumber.textColor = [UIColor whiteColor];
    
    self.lblStatus.text = @"Not Expected";
    self.lblStatus.backgroundColor = [UIColor blackColor];
}

- (void) setAsRecorded
{
    self.imgAid.hidden = YES;
    self.imgDroppedHere.hidden = YES;
    
    self.backgroundColor = [UIColor whiteColor];
    self.lblBibNumber.textColor = [UIColor colorWithRed:1.0/255 green:168.0/255 blue:39.0/255 alpha:1];
    self.lblStatus.backgroundColor = [UIColor colorWithRed:1.0/255 green:168.0/255 blue:39.0/255 alpha:1];
    
    self.lblStatus.text = @"Recorded";
}

@end
