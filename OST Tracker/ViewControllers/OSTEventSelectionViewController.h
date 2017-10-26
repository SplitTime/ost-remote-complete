//
//  OSTEventSelectionViewController.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "IQDropDownTextField.h"
#import "EventModel.h"

@interface OSTEventSelectionViewController : UIViewController

@property (assign, nonatomic) BOOL changeStation;
@property (weak, nonatomic) IBOutlet UIButton *btnNext;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtEvent;
@property (weak, nonatomic) IBOutlet IQDropDownTextField *txtStation;
@property (strong, nonatomic) NSManagedObjectContext * tempContext;
@property (strong, nonatomic) NSMutableArray * events;
@property (weak, nonatomic) IBOutlet UIButton *btnCancel;
@property (strong, nonatomic) EventModel * selectedEvent;
@property (strong, nonatomic) NSArray * combinedSplitAttributes;
@property (weak, nonatomic) IBOutlet UIImageView *imgTriangleAidStation;
@property (assign, nonatomic) BOOL eventsLoaded;
@property (nonatomic, strong) NSMutableArray * eventStrings;

@end
