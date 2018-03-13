//
//  OSTCrossCheckHeader.m
//  OST Tracker
//
//  Created by Luciano Castro on 10/24/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTCrossCheckHeader.h"

@implementation OSTCrossCheckHeader

- (IBAction)selectionChanged:(id)sender
{
    self.splitChange([self.segLocation titleForSegmentAtIndex:[self.segLocation selectedSegmentIndex]]);
}

@end
