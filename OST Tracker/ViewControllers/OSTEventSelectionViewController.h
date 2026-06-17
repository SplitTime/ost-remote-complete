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
@property (strong, nonatomic) NSArray * unpairedDataEntryGroups;
@property (weak, nonatomic) IBOutlet UIImageView *imgTriangleAidStation;
@property (assign, nonatomic) BOOL eventsLoaded;
@property (nonatomic, strong) NSMutableArray * eventStrings;

/// Loads the live events list (network + CoreData import) and presents a fresh
/// event-selection screen from `presenter`. Moved out of the (now Swift) login
/// VC so the event screen owns its own data loading. `completion` is called with
/// nil on success (after presenting) or an error (alerts are shown internally).
+ (void)loadEventDataAndPresentFrom:(UIViewController *)presenter
                         completion:(void (^ _Nullable)(NSError * _Nullable error))completion;

@end
