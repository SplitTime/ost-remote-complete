//
//  OSTRunnerTrackerViewController.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/13/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTRunnerTrackerViewController.h"
#import "EntryModel.h"
#import "CurrentCourse.h"
#import "OSTSessionManager.h"
#import "EffortModel.h"
#import "UIView+Additions.h"
#import "OSTEditEntryViewController.h"
#import "IQKeyboardManager.h"
#import "APNumberPad.h"
#import "OSTSound.h"

@interface OSTRunnerTrackerViewController () <APNumberPadDelegate>

@property (weak, nonatomic) IBOutlet UIView *numberPadContainerView;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblTime;
@property (strong, nonatomic) NSTimer * timer;
@property (weak, nonatomic) IBOutlet UISwitch *swchPaser;
@property (weak, nonatomic) IBOutlet UIButton *btnLeft;
@property (weak, nonatomic) IBOutlet UIButton *btnRight;
@property (weak, nonatomic) IBOutlet UISwitch *swchStoppedHere;
@property (weak, nonatomic) IBOutlet UIView *pacerAndAidView;
@property (weak, nonatomic) IBOutlet UIButton *btnRightMenu;
@property (weak, nonatomic) IBOutlet UILabel *lblPersonAdded;
@property (strong, nonatomic) NSString * splitId;
@property (strong, nonatomic) NSArray * splitIds;
@property (weak, nonatomic) IBOutlet UILabel *lblOutTimeBadge;
@property (weak, nonatomic) IBOutlet UILabel *lblInTimeBadge;
@property (weak, nonatomic) IBOutlet UILabel *lblRunnerInfo;
@property (strong, nonatomic) NSString * dayString;
@property (weak, nonatomic) IBOutlet UILabel *lblAdded;
@property (strong, nonatomic) EffortModel * racer;
@property (strong, nonatomic) NSDate * entryDateTime;
@property (strong, nonatomic) EntryModel * lastEntry;
@property (strong, nonatomic) NSString * leftBitKey;
@property (strong, nonatomic) NSString * rightBitKey;
@property (weak, nonatomic) IBOutlet UILabel *lblWithPacer;


@end

@implementation OSTRunnerTrackerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.timer = [NSTimer scheduledTimerWithTimeInterval: 0.1
                                                              target: self
                                                            selector:@selector(onTick:)
                                                            userInfo: nil repeats:YES];
    
    self.splitId = [CurrentCourse getCurrentCourse].splitId;
    
    APNumberPad *numberPad = [APNumberPad numberPadWithDelegate:self];
    [numberPad.leftFunctionButton setTitle:@"*" forState:UIControlStateNormal];
    numberPad.leftFunctionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    numberPad.frame = self.numberPadContainerView.bounds;
    numberPad.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    numberPad.backgroundColor = [UIColor clearColor];
    [self.numberPadContainerView addSubview:numberPad];
    [numberPad setTextField:self.txtBibNumber];
    
    if (IS_IPHONE_5)
    {
        self.pacerAndAidView.top = self.pacerAndAidView.top - 25;
        self.btnLeft.top = self.btnLeft.top - 55;
        self.btnRight.top = self.btnRight.top - 55;
        self.lblInTimeBadge.top = self.lblOutTimeBadge.top = self.lblOutTimeBadge.top - 55;
        self.numberPadContainerView.top = self.numberPadContainerView.top - 60;
        self.numberPadContainerView.height = self.numberPadContainerView.height + 60;
    }
    if (IS_IPHONE_X)
    {
        self.lblTitle.numberOfLines = 1;
        self.lblTitle.bottom = self.lblTitle.bottom + 7;
        self.btnRightMenu.bottom = self.btnRightMenu.bottom + 7;
        self.numberPadContainerView.height = self.numberPadContainerView.height - 30;
    }
    if (IS_IPAD)
    {
        self.numberPadContainerView.top = self.numberPadContainerView.top + 20;
        self.numberPadContainerView.height = self.numberPadContainerView.height - 50;
        self.lblPersonAdded.font = [UIFont fontWithName:self.lblPersonAdded.font.familyName size:20];
        self.lblAdded.font = [UIFont fontWithName:self.lblAdded.font.familyName size:20];
        self.lblRunnerInfo.font = [UIFont fontWithName:self.lblRunnerInfo.font.familyName size:20];
    }
    
    self.lblOutTimeBadge.layer.cornerRadius = self.lblOutTimeBadge.width/2;
    self.lblInTimeBadge.layer.cornerRadius = self.lblInTimeBadge.width/2;
    self.lblOutTimeBadge.clipsToBounds = YES;
    self.lblInTimeBadge.clipsToBounds = YES;
    
    self.lblOutTimeBadge.hidden = YES;
    self.lblInTimeBadge.hidden = YES;
    
    [self.btnLeft setBackgroundImage:[UIImage imageNamed:@"GrayButton"] forState:UIControlStateHighlighted];
    [self.btnRight setBackgroundImage:[UIImage imageNamed:@"GrayButton"] forState:UIControlStateHighlighted];
    
    [self.txtBibNumber addObserver:self forKeyPath:@"text"
                       options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                       context:nil];
}

-(void)onTick:(NSTimer *)timer
{
    NSDate * date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"HH:mm:ss"];
    self.lblTime.text = [dateFormatter stringFromDate:date];
    
    dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd"];
    self.dayString = [dateFormatter stringFromDate:date];
    
    self.entryDateTime = date;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [IQKeyboardManager sharedManager].enableAutoToolbar = NO;
    self.lblTitle.text = [CurrentCourse getCurrentCourse].splitName;
    
    self.btnLeft.width = self.view.width/2 - 18;
    self.btnRight.width = self.view.width/2 - 18;
    
    self.btnLeft.left = 0;
    self.btnRight.right = self.view.width;
    
    NSArray * entries = [CurrentCourse getCurrentCourse].splitAttributes[@"entries"];
    
    NSArray * splitEntriesIn = [entries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"subSplitKind == %@",@"in"]];
    NSArray * splitEntriesOut = [entries filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"subSplitKind == %@",@"out"]];
    
    if (splitEntriesIn.count == 1 && splitEntriesOut.count == 0)
    {
        self.btnLeft.width = self.btnRight.right - self.btnLeft.left;
        self.btnRight.hidden = YES;
        
        [self.btnLeft setTitle:splitEntriesIn[0][@"label"] forState:UIControlStateNormal];
        self.leftBitKey = @"in";
    }
    if (splitEntriesIn.count == 0 && splitEntriesOut.count == 1)
    {
        self.btnRight.width = self.btnRight.right - self.btnLeft.left;
        self.btnLeft.hidden = YES;
        self.btnRight.left = self.btnLeft.left;
        self.rightBitKey = @"out";
        
        [self.btnRight setTitle:splitEntriesOut[0][@"label"] forState:UIControlStateNormal];
    }
    else if(splitEntriesIn.count == 1 && splitEntriesOut.count == 1)
    {
        self.btnRight.hidden = NO;
        self.btnLeft.hidden = NO;
        
        self.btnLeft.width = self.view.width/2 - 18;
        self.btnRight.width = self.view.width/2 - 18;
        
        self.btnLeft.left = 0;
        self.btnRight.right = self.view.width;
        
        [self.btnLeft setTitle:splitEntriesIn[0][@"label"] forState:UIControlStateNormal];
        [self.btnRight setTitle:splitEntriesOut[0][@"label"] forState:UIControlStateNormal];
        self.leftBitKey = @"in";
        self.rightBitKey = @"out";
    }
    else if(splitEntriesIn.count == 2)
    {
        self.btnRight.hidden = NO;
        self.btnLeft.hidden = NO;
        
        self.btnLeft.width = self.view.width/2 - 18;
        self.btnRight.width = self.view.width/2 - 18;
        
        self.btnLeft.left = 0;
        self.btnRight.right = self.view.width;
        
        [self.btnLeft setTitle:splitEntriesIn[0][@"label"] forState:UIControlStateNormal];
        [self.btnRight setTitle:splitEntriesIn[1][@"label"] forState:UIControlStateNormal];
        self.leftBitKey = @"in";
        self.rightBitKey = @"in";
    }
    else if(splitEntriesOut.count == 2)
    {
        self.btnRight.hidden = NO;
        self.btnLeft.hidden = NO;
        
        self.btnLeft.width = self.view.width/2 - 18;
        self.btnRight.width = self.view.width/2 - 18;
        
        self.btnLeft.left = 0;
        self.btnRight.right = self.view.width;
        
        [self.btnLeft setTitle:splitEntriesOut[0][@"label"] forState:UIControlStateNormal];
        [self.btnRight setTitle:splitEntriesOut[1][@"label"] forState:UIControlStateNormal];
        self.leftBitKey = @"out";
        self.rightBitKey = @"out";
    }
    if (![CurrentCourse getCurrentCourse].monitorPacers.boolValue)
    {
        self.lblWithPacer.hidden = YES;
        self.swchPaser.hidden = YES;
        self.pacerAndAidView.height = 43;
    }
    else
    {
        self.lblWithPacer.hidden = NO;
        self.swchPaser.hidden = NO;
        self.pacerAndAidView.height = 86;
    }
    self.lblInTimeBadge.right = self.btnLeft.right - 5;
}

- (IBAction)onRight:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}

- (void) cleanData
{
    self.lastEntry = nil;
    self.lblAdded.hidden = YES;
    self.lblPersonAdded.hidden = YES;
    self.lblRunnerInfo.hidden = YES;
    self.swchPaser.on = NO;
    self.swchStoppedHere.on = NO;
    self.txtBibNumber.text = nil;
    self.lblInTimeBadge.hidden = YES;
    self.lblOutTimeBadge.hidden = YES;
}

- (IBAction)onEntryButton:(id)sender
{
    [[OSTSound shared] play:@"click"];
    
    [self.txtBibNumber removeObserver:self forKeyPath:@"text"];
    [[UIDevice currentDevice] playInputClick];
    
    self.lblOutTimeBadge.hidden = YES;
    self.lblInTimeBadge.hidden = YES;
    CurrentCourse * course = [CurrentCourse getCurrentCourse];

    EntryModel * entry = [EntryModel MR_createEntity];
    
    if (self.txtBibNumber.text.length == 0)
    {
        entry.bibNumber = @"-1";
        self.racer = nil;
    }
    else entry.bibNumber = self.txtBibNumber.text;
    if (sender == self.btnLeft)
        entry.bitKey = self.leftBitKey;
    else entry.bitKey = self.rightBitKey;
    
    int timezoneoffset = (int)([[NSTimeZone systemTimeZone] secondsFromGMT])/60/60;
    if (timezoneoffset < 0)
        entry.absoluteTime = [NSString stringWithFormat:@"%@ %@%02d:00",self.dayString, self.lblTime.text,timezoneoffset];
    else entry.absoluteTime = [NSString stringWithFormat:@"%@ %@+%02d:00",self.dayString, self.lblTime.text,timezoneoffset];
    entry.displayTime = self.lblTime.text;
    if (self.swchPaser.on)
        entry.withPacer = @"true";
    else entry.withPacer = @"false";
    if (self.swchStoppedHere.on)
        entry.stoppedHere = @"true";
    else entry.stoppedHere = @"false";
    
    entry.courseName = course.eventName;
    entry.splitName = course.splitName;
    entry.combinedCourseId = course.eventId;
    
    for (NSDictionary * dict in course.dataEntryGroups)
    {
        if ([dict[@"title"] isEqualToString:course.splitName])
        {
            if ([sender tag] == 1)
            {
                entry.entryCourseId = [self.racer.eventId stringValue];
                entry.splitName = dict[@"entries"][0][@"splitName"];
            }
            else if ([sender tag] == 2)
            {
                entry.entryCourseId = [self.racer.eventId stringValue];
                entry.splitName = dict[@"entries"][1][@"splitName"];
            }
        }
    }

    entry.entryTime = self.entryDateTime;
    
    entry.timeEntered = [NSDate date];
    
    if (self.racer)
    {
        entry.fullName = self.racer.fullName;
    }
    
    entry.source = [NSString stringWithFormat:@"ost-remote-%@",[OSTSessionManager getUUIDString]];
    
    [[NSManagedObjectContext MR_defaultContext] processPendingChanges];
    [[NSManagedObjectContext MR_defaultContext] MR_saveOnlySelfAndWait];
    
    self.lblRunnerInfo.hidden = YES;
    self.lblAdded.hidden = NO;
    self.lblPersonAdded.hidden = NO;
    
    NSString * entryName = entry.fullName;
    
    if (entryName.length == 0)
    {
        entryName = @"Bib not found";
    }
    
    self.lblPersonAdded.text = [NSString stringWithFormat:@"%@ (%@)", entryName, entry.displayTime];
    self.lblAdded.text = self.racer.flexibleGeolocation ? : @"";
    self.lastEntry = entry;
    
    self.txtBibNumber.text = @"";
    self.swchPaser.on = NO;
    self.swchStoppedHere.on = NO;
    [self.txtBibNumber addObserver:self forKeyPath:@"text"
                           options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld
                           context:nil];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string
{
    
    if ([string rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet].invertedSet].location != NSNotFound)
    {
        return NO;
    }
    
    return YES;
}

- (IBAction)onRunnerInfo:(id)sender
{
    if (self.lastEntry)
    {
        OSTEditEntryViewController * editVC = [[OSTEditEntryViewController alloc] initWithNibName:nil bundle:nil];
        [self presentViewController:editVC animated:YES completion:nil];
        __weak OSTRunnerTrackerViewController * weakSelf = self;
        editVC.entryHasBeenDeletedBlock = ^
        {
            weakSelf.lastEntry = nil;
            weakSelf.lblPersonAdded.hidden = YES;
            weakSelf.lblAdded.hidden = YES;
        };
        
        editVC.entryHasBeenUpdatedBlock = ^
        {
            NSString * entryName = weakSelf.lastEntry.fullName;
            
            if (entryName.length == 0)
            {
                entryName = @"Bib not found";
            }
            
            weakSelf.lblPersonAdded.text = [NSString stringWithFormat:@"#%@ %@ (%@)", [weakSelf.lastEntry.bibNumber isEqualToString:@"-1"]?@"":weakSelf.lastEntry.bibNumber, entryName, weakSelf.lastEntry.displayTime];
            
        };
        
        [editVC configureWithEntry:self.lastEntry];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    
    [self txtBibNumberChanged:nil];
}

- (IBAction)txtBibNumberChanged:(id)sender
{
    self.lblRunnerInfo.hidden = NO;
    self.lastEntry = nil;
    
    self.lblAdded.hidden = YES;
    self.lblPersonAdded.hidden = YES;
    
    self.lblOutTimeBadge.hidden = YES;
    self.lblInTimeBadge.hidden = YES;
    self.racer = nil;
    self.lblRunnerInfo.textColor = [UIColor darkGrayColor];
    if (self.txtBibNumber.text.length == 0)
    {
        self.lblRunnerInfo.text = @"";
    }
    else
    {
        EffortModel * effort = nil;
        
        if (![self.txtBibNumber.text containsString:@"*"])
        {
            effort = [EffortModel MR_findFirstWithPredicate:[NSPredicate predicateWithFormat:@"bibNumber == %@", [NSDecimalNumber decimalNumberWithString:self.txtBibNumber.text]]];
        }
        
        if (effort)
        {
            if ([effort checkIfEffortShouldBeInSplit:[CurrentCourse getCurrentCourse].splitName])
            {
                self.racer = effort;
                self.lblPersonAdded.hidden = NO;
                self.lblAdded.hidden = NO;
                self.lblPersonAdded.text = effort.fullName;
                self.lblAdded.text = effort.flexibleGeolocation;
                self.lblRunnerInfo.text = @"";
            }
            else
            {
                self.lblRunnerInfo.text = @"Bib Not Found";
                self.lblRunnerInfo.textColor = [UIColor redColor];
            }
            
            if ([[EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bitKey == %@ && bibNumber == %@ && combinedCourseId == %@ && splitName == %@",self.leftBitKey,self.txtBibNumber.text,[CurrentCourse getCurrentCourse].eventId,self.btnLeft.titleLabel.text]] count])
            {
                self.lblInTimeBadge.hidden = NO;
                if ([CurrentCourse getCurrentCourse].multiLap.boolValue)
                {
                    self.lblInTimeBadge.text = [NSString stringWithFormat:@"%ld",(unsigned long)[[EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bitKey == %@ && bibNumber == %@ && combinedCourseId == %@ && splitName ==  %@",self.leftBitKey,self.txtBibNumber.text,[CurrentCourse getCurrentCourse].eventId,self.btnLeft.titleLabel.text]] count]];
                }
                else
                {
                    self.lblInTimeBadge.text = @"!";
                }
            }
            
            if ([[EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bitKey == %@ && bibNumber == %@ && combinedCourseId == %@ && splitName == %@",self.rightBitKey,self.txtBibNumber.text,[CurrentCourse getCurrentCourse].eventId,self.btnRight.titleLabel.text]] count])
            {
                self.lblOutTimeBadge.hidden = NO;
                if ([CurrentCourse getCurrentCourse].multiLap.boolValue)
                {
                    self.lblOutTimeBadge.text =  [NSString stringWithFormat:@"%ld",(long)[[EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bitKey == %@ && bibNumber == %@ && combinedCourseId == %@ && splitName == %@",self.rightBitKey,self.txtBibNumber.text,self.btnRight.titleLabel.text]] count]];
                }
                else
                {
                    self.lblOutTimeBadge.text = @"!";
                }
            }

        }
        else
        {
            self.lblRunnerInfo.text = @"Bib Not Found";
            self.lblRunnerInfo.textColor = [UIColor redColor];
        }
    }
}

- (void) dealloc
{
    [self.txtBibNumber removeObserver:self forKeyPath:@"text"];
}

#pragma mark - APNumberPadDelegate

- (void)numberPad:(APNumberPad *)numberPad functionButtonAction:(UIButton *)functionButton textInput:(UIResponder<UITextInput> *)textInput {
    if ([textInput isKindOfClass:[UITextField class]])
    {
        ((UITextField*)(textInput)).text = [NSString stringWithFormat:@"%@%@",((UITextField*)(textInput)).text,@"*"];
    }
    else [textInput insertText:@"*"];
}

@end
