//
//  OSTCrossCheckCell.m
//  OST Tracker
//
//  Created by Luciano Castro on 10/20/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTCrossCheckCell.h"

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
}

@end
