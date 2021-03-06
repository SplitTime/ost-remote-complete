//
//  OSTCrossCheckHeader.h
//  OST Tracker
//
//  Created by Luciano Castro on 10/24/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface OSTCrossCheckHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UILabel *lblStationName;
@property (weak, nonatomic) IBOutlet UISegmentedControl *segLocation;
@property (nonatomic, copy) void (^splitChange)(NSString * newSplitName);

@end
