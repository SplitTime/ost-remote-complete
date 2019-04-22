//
//  OSTRunnerTrackerViewController.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/13/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OSTBaseViewController.h"

@interface OSTRunnerTrackerViewController : OSTBaseViewController

@property (weak, nonatomic) IBOutlet UITextField *txtBibNumber;

- (void) cleanData;


@end
