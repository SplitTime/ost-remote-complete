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
#import "OSTRunnerBadge.h"

@interface OSTRunnerTrackerViewController () <APNumberPadDelegate>

@property (weak, nonatomic) IBOutlet UIView *numberPadContainerView;
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *lblTime;
@property (strong, nonatomic) NSTimer * timer;
@property (weak, nonatomic) IBOutlet UIButton *btnLeft;
@property (weak, nonatomic) IBOutlet UIButton *btnRight;
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
@property (weak, nonatomic) IBOutlet UIButton *btnStopped;
@property (weak, nonatomic) IBOutlet UIButton *btnPacer;
@property (weak, nonatomic) IBOutlet UIView *headerContainerView;
@property (strong, nonatomic) NSString * rightBitKey;
@property (weak, nonatomic) IBOutlet UILabel *lblWithPacer;
@property (weak, nonatomic) IBOutlet UILabel *lblSecondaryInfo;
@property (weak, nonatomic) IBOutlet UIView *timeContainerView;
@property (weak, nonatomic) IBOutlet UIView *separatoryLine;
@property (weak, nonatomic) IBOutlet UILabel *lblTimeOfTheDay;
@property (weak, nonatomic) IBOutlet OSTRunnerBadge *runnerBadge;

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
    self.btnLeft.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.btnRight.titleLabel.textAlignment = NSTextAlignmentCenter;
    
    [self.lblInTimeBadge removeFromSuperview];
    [self.lblOutTimeBadge removeFromSuperview];
    
    [self.btnLeft addSubview:self.lblInTimeBadge];
    [self.btnRight addSubview:self.lblOutTimeBadge];
    
    self.lblInTimeBadge.top = 0;
    self.lblInTimeBadge.right = self.btnLeft.width;
    self.lblOutTimeBadge.top = 0;
    self.lblOutTimeBadge.right = self.btnRight.width;
    
    if (IS_IPHONE_5)
    {
        self.numberPadContainerView.height=220;
        self.numberPadContainerView.bottom = self.view.bottom;
        /*self.pacerAndAidView.top = self.pacerAndAidView.top - 25;
        self.btnLeft.top = self.btnLeft.top - 55;
        self.btnRight.top = self.btnRight.top - 55;
        self.lblInTimeBadge.top = self.lblOutTimeBadge.top = self.lblOutTimeBadge.top - 55;
        self.numberPadContainerView.top = self.numberPadContainerView.top - 60;
        self.numberPadContainerView.height = self.numberPadContainerView.height + 60;*/
    }
    if (IS_IPHONE_6P)
    {
        self.numberPadContainerView.height = self.view.height/2-17;
        self.numberPadContainerView.top = self.view.height/2+17;
    }
    if (IS_IPHONE_X || IS_IPHONE_XR)
    {
        self.headerContainerView.height = 190;
        if (IS_IPHONE_XR)
        {
            self.headerContainerView.height = 210;
            self.numberPadContainerView.height = self.view.height/2-18;
            self.numberPadContainerView.top = self.view.height/2+1;
        }
        else
        {
            self.numberPadContainerView.height = self.view.height/2 - 40;
            self.numberPadContainerView.top = self.view.height/2 + 15;
        }
        self.pacerAndAidView.top = self.headerContainerView.bottom;
        self.lblTitle.numberOfLines = 1;
        self.lblTitle.bottom = self.lblTitle.bottom + 7;
        self.btnRightMenu.bottom = self.btnRightMenu.bottom + 7;
        self.btnRight.top = self.btnLeft.top = self.pacerAndAidView.bottom + 10;
        self.txtBibNumber.font = [UIFont fontWithName:@"Helvetica Bold" size:75];
    }
    if (IS_IPAD)
    {
        self.numberPadContainerView.height=self.view.height/2;
        self.numberPadContainerView.top = self.view.height/2;
        
        self.headerContainerView.height = 210;
        self.pacerAndAidView.top = self.headerContainerView.bottom;
        self.txtBibNumber.font = [UIFont fontWithName:@"Helvetica Bold" size:75];
        self.btnRight.top = self.btnLeft.top = self.pacerAndAidView.bottom + 10;
        self.btnRight.height = self.btnLeft.height = 143;
        
        self.btnRight.titleLabel.font = self.btnLeft.titleLabel.font = [UIFont fontWithName:@"Helvetica Bold" size:33];
        self.lblPersonAdded.font = [UIFont fontWithName:@"Helvetica Bold" size:36];
        self.lblAdded.font = [UIFont fontWithName:@"Helvetica" size:28];
        self.lblSecondaryInfo.font = [UIFont fontWithName:@"Helvetica" size:28];
        self.lblAdded.top = self.lblAdded.top + 12;
        self.lblTime.font = [UIFont fontWithName:@"Helvetica Bold" size:36];
        self.txtBibNumber.font = [UIFont fontWithName:@"Helvetica Bold" size:100];
        self.lblTimeOfTheDay.font = [UIFont fontWithName:@"Helvetica Bold" size:20];
        self.separatoryLine.right += 50;
        self.lblTimeOfTheDay.width += 30;
        self.lblTimeOfTheDay.height += 6;
        self.lblTimeOfTheDay.top-=10;
        self.lblTimeOfTheDay.left+=5;
        self.lblTime.width +=50;
        self.txtBibNumber.width += 50;
        self.lblTime.height += 15;
        self.btnPacer.width = self.btnStopped.width = 174;
        self.btnPacer.height = self.btnStopped.height = 56;
        self.lblSecondaryInfo.top -= 50;
        self.lblSecondaryInfo.height += 30;
    }
    
    APNumberPad *numberPad = [APNumberPad numberPadWithDelegate:self];
    [numberPad.leftFunctionButton setTitle:@"*" forState:UIControlStateNormal];
    numberPad.leftFunctionButton.titleLabel.adjustsFontSizeToFitWidth = YES;
    numberPad.frame = self.numberPadContainerView.bounds;
    numberPad.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    numberPad.backgroundColor = [UIColor clearColor];
    [self.numberPadContainerView addSubview:numberPad];
    [numberPad setTextField:self.txtBibNumber];
    
    
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
    
    self.btnLeft.width = self.view.width/2 - 4;
    self.btnRight.width = self.view.width/2 - 4;
    
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
        
        self.btnLeft.width = self.view.width/2 - 4;
        self.btnRight.width = self.view.width/2 - 4;
        
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
        
        self.btnLeft.width = self.view.width/2 - 4;
        self.btnRight.width = self.view.width/2 - 4;
        
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
        
        self.btnLeft.width = self.view.width/2 - 4;
        self.btnRight.width = self.view.width/2 - 4;
        
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
        self.btnPacer.hidden = YES;
        self.btnStopped.center = CGPointMake(self.pacerAndAidView.width/2, self.pacerAndAidView.height/2);
    }
    else
    {
        self.lblWithPacer.hidden = NO;
        self.btnPacer.hidden = NO;
        self.btnStopped.center = CGPointMake(self.pacerAndAidView.width/4, self.pacerAndAidView.height/2);
        self.btnPacer.center = CGPointMake(self.pacerAndAidView.width/4*3, self.pacerAndAidView.height/2);
    }
    
    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation))
    {
        self.btnRight.width = self.btnLeft.width = self.view.height/2.7;
        self.btnLeft.left = 10;
        self.btnLeft.top = self.view.width/2.5;
        
        self.btnRight.right = self.view.right-10;
        self.btnRight.top = self.btnLeft.top;
    }
}

- (IBAction)onRight:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}

- (void) cleanData
{
    self.lastEntry = nil;
    self.runnerBadge.hidden = YES;
    self.lblAdded.hidden = YES;
    self.lblRunnerInfo.hidden = YES;
    self.btnPacer.selected = NO;
    self.btnStopped.selected = NO;
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
    if (self.btnPacer.selected)
        entry.withPacer = @"true";
    else entry.withPacer = @"false";
    if (self.btnStopped.selected)
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
    else
    {
        [[NSNotificationCenter defaultCenter] postNotificationName:OSTRunnerTrackerViewControllerDidRegisterBibNotification object:nil];
    }
    
    self.lblPersonAdded.text = [NSString stringWithFormat:@"%@", entryName];
    self.lblAdded.text = self.racer.flexibleGeolocation ? : @"";
    self.lastEntry = entry;
    self.runnerBadge.hidden = entry == nil;
    
    if (!self.runnerBadge.hidden)
    {
        [self.runnerBadge updateWithModel:[self runnerBadgeViewModel]];
    }
    
    self.txtBibNumber.text = @"";
    self.btnPacer.selected = NO;
    self.btnStopped.selected = NO;
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
            weakSelf.runnerBadge.hidden = YES;
            weakSelf.lblAdded.hidden = YES;

            weakSelf.lblPersonAdded.text = @"Enter Bib Number";
            weakSelf.lblRunnerInfo.text = @"";
            weakSelf.lblSecondaryInfo.text = @"";
            weakSelf.lblAdded.text = @"";
            weakSelf.lblRunnerInfo.textColor = [UIColor colorWithRed:159.0/255 green:34.0/255 blue:40.0/255 alpha:1];
            weakSelf.txtBibNumber.textColor = [UIColor colorWithRed:159.0/255 green:34.0/255 blue:40.0/255 alpha:1];
        };
        
        editVC.entryHasBeenUpdatedBlock = ^ (EffortModel* effort)
        {
            NSString * entryName = weakSelf.lastEntry.fullName;
            
            if (entryName.length == 0)
            {
                weakSelf.lblPersonAdded.text = @"Bib not found";
                weakSelf.lblRunnerInfo.text = @"";
                weakSelf.lblSecondaryInfo.text = @"";
                weakSelf.lblAdded.text = @"";
                weakSelf.lblRunnerInfo.textColor = [UIColor colorWithRed:159.0/255 green:34.0/255 blue:40.0/255 alpha:1];
                weakSelf.txtBibNumber.textColor = [UIColor colorWithRed:159.0/255 green:34.0/255 blue:40.0/255 alpha:1];
            }
            else
            {
                weakSelf.lblAdded.hidden = NO;
                weakSelf.lblPersonAdded.text = effort.fullName;
                weakSelf.lblAdded.text = effort.flexibleGeolocation;
                
                self.lblRunnerInfo.text = @"";
                
                NSMutableString *secondaryInfo = [NSMutableString new];
                NSString *eventShortName = [self getEffortEventShortName:effort];
                
                if (eventShortName != nil)
                {
                    [secondaryInfo appendFormat:@"%@\n", eventShortName];
                }
                
                if (effort.gender)
                    [secondaryInfo appendString:[effort.gender capitalizedString]];
                
                if(effort.age != nil)
                {
                    if (effort.gender)
                        [secondaryInfo appendFormat:@" (%@)", effort.age];
                    else [secondaryInfo appendFormat:@"%@", effort.age];
                }
                
                weakSelf.lblSecondaryInfo.text = secondaryInfo;
            }
        };
        
        [editVC configureWithEntry:self.lastEntry];
    }
}
- (IBAction)onButtonPacer:(id)sender
{
   self.btnPacer.selected = !self.btnPacer.selected;
    [[OSTSound shared] play:@"ost-remote-switch-1"];
}

- (IBAction)onBtnStopped:(id)sender
{
    self.btnStopped.selected = !self.btnStopped.selected;
    [[OSTSound shared] play:@"ost-remote-switch-1"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object
                        change:(NSDictionary *)change context:(void *)context {
    
    [self txtBibNumberChanged:nil];
}

- (IBAction)txtBibNumberChanged:(id)sender
{
    self.lblRunnerInfo.hidden = NO;
    self.lastEntry = nil;
    self.runnerBadge.hidden = YES;
    
    self.lblAdded.hidden = YES;
    
    self.lblOutTimeBadge.hidden = YES;
    self.lblInTimeBadge.hidden = YES;
    self.racer = nil;
    self.lblRunnerInfo.textColor = [UIColor darkGrayColor];
    self.txtBibNumber.textColor = [UIColor blackColor];
    if (self.txtBibNumber.text.length == 0)
    {
        self.lblPersonAdded.text = @"Enter Bib Number";
        self.lblRunnerInfo.text = @"";
        self.lblSecondaryInfo.text = @"";
        self.lblAdded.text = @"";
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
            //if ([effort checkIfEffortShouldBeInSplit:[CurrentCourse getCurrentCourse].splitName])
            {
                self.racer = effort;
                self.lblAdded.hidden = NO;
                self.lblPersonAdded.text = effort.fullName;
                self.lblAdded.text = effort.flexibleGeolocation;
                //self.lblAdded.text = "
                self.lblRunnerInfo.text = @"";
                
                NSMutableString *secondaryInfo = [NSMutableString new];
                NSString *eventShortName = [self getEffortEventShortName:effort];
                
                if (eventShortName != nil)
                {
                    [secondaryInfo appendFormat:@"%@\n", eventShortName];
                }
                
                if (effort.gender)
                    [secondaryInfo appendString:[effort.gender capitalizedString]];
                
                if(effort.age != nil)
                {
                    if (effort.gender)
                        [secondaryInfo appendFormat:@" (%@)", effort.age];
                    else [secondaryInfo appendFormat:@"%@", effort.age];
                }
                
                self.lblSecondaryInfo.text = secondaryInfo;
            }
            /*
            else
            {
                self.lblRunnerInfo.text = @"Bib Not Found";
                self.lblRunnerInfo.textColor = [UIColor redColor];
            }
            */
            
            if ([[EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bitKey == %@ && bibNumber == %@ && combinedCourseId == %@ && splitName == %@",self.leftBitKey,self.txtBibNumber.text,[CurrentCourse getCurrentCourse].eventId,[CurrentCourse getCurrentCourse].splitName]] count])
            {
                self.lblInTimeBadge.hidden = NO;
                if ([CurrentCourse getCurrentCourse].multiLap.boolValue)
                {
                    self.lblInTimeBadge.text = [NSString stringWithFormat:@"%ld",(unsigned long)[[EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bitKey == %@ && bibNumber == %@ && combinedCourseId == %@ && splitName ==  %@",self.leftBitKey,self.txtBibNumber.text,[CurrentCourse getCurrentCourse].eventId,[CurrentCourse getCurrentCourse].splitName]] count]];
                }
                else
                {
                    self.lblInTimeBadge.text = @"!";
                    [[OSTSound shared] play:@"ost-remote-bib-wrong-event-1"];
                }
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
                    [[OSTSound shared] play:@"ost-remote-bib-wrong-event-1"];
                }
            }
            
            if ([[EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bitKey == %@ && bibNumber == %@ && combinedCourseId == %@ && splitName == %@",self.rightBitKey,self.txtBibNumber.text,[CurrentCourse getCurrentCourse].eventId,[CurrentCourse getCurrentCourse].splitName]] count])
            {
                self.lblOutTimeBadge.hidden = NO;
                if ([CurrentCourse getCurrentCourse].multiLap.boolValue)
                {
                    self.lblOutTimeBadge.text =  [NSString stringWithFormat:@"%ld",(long)[[EntryModel MR_findAllWithPredicate:[NSPredicate predicateWithFormat:@"bitKey == %@ && bibNumber == %@ && combinedCourseId == %@ && splitName == %@",self.rightBitKey,self.txtBibNumber.text,[CurrentCourse getCurrentCourse].splitName]] count]];
                }
                else
                {
                    self.lblOutTimeBadge.text = @"!";
                    [[OSTSound shared] play:@"ost-remote-bib-wrong-event-1"];
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
                    [[OSTSound shared] play:@"ost-remote-bib-wrong-event-1"];
                }
            }

        }
        else
        {
            self.lblRunnerInfo.text = @"Bib Not Found";
            self.lblRunnerInfo.textColor = [UIColor colorWithRed:159.0/255 green:34.0/255 blue:40.0/255 alpha:1];
            self.txtBibNumber.textColor = [UIColor colorWithRed:159.0/255 green:34.0/255 blue:40.0/255 alpha:1];
            self.lblPersonAdded.text = @"";
            self.lblSecondaryInfo.text = @"";
            [[OSTSound shared] play:@"ost-remote-bib-not-found"];
        }
    }
}

- (NSString *)getEffortEventShortName:(EffortModel *)effort
{
    return [CurrentCourse getCurrentCourse].eventShortNames[[NSString stringWithFormat:@"%@", effort.eventId]];
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

#pragma mark - Rotation

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id <UIViewControllerTransitionCoordinator>)coordinator
{
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];

    UIInterfaceOrientation interfaceOrientation = [[UIApplication sharedApplication] statusBarOrientation];
    if (UIInterfaceOrientationIsPortrait(interfaceOrientation))
    {
        self.btnRight.width = self.btnLeft.width = self.view.width/2.7;
        self.btnLeft.left = 10;
        self.btnLeft.top = self.view.height/2.5;
        
        self.btnRight.right = self.view.right-10;
        self.btnRight.top = self.btnLeft.top;
    }
    else
    {
        if (self.btnRight.hidden)
        {
            self.btnRight.top = self.btnLeft.top = self.pacerAndAidView.bottom + 10;
            self.btnRight.width = self.btnLeft.width = self.view.height;
            self.btnRight.right = self.view.right;
            self.btnLeft.left = self.view.left;
            self.btnRight.height = self.btnLeft.height = 143;
        }
        else if (self.btnLeft.hidden)
        {
            self.btnRight.top = self.btnLeft.top = self.pacerAndAidView.bottom + 10;
            self.btnRight.width = self.btnLeft.width = self.view.height;
            self.btnRight.right = self.view.right;
            self.btnLeft.left = self.view.left;
            self.btnRight.height = self.btnLeft.height = 143;
        }
        else
        {
            self.btnRight.top = self.btnLeft.top = self.pacerAndAidView.bottom + 10;
            self.btnRight.width = self.btnLeft.width = self.view.height/2 - 4;
            self.btnRight.right = self.view.right;
            self.btnLeft.left = self.view.left;
            self.btnRight.height = self.btnLeft.height = 143;
        }
        
    }
}

- (OSTRunnerBadgeViewModel *)runnerBadgeViewModel
{
    OSTRunnerBadgeViewModel *viewModel = [OSTRunnerBadgeViewModel new];
    
    viewModel.bibNumber = [NSString stringWithFormat:@"%@", self.racer.bibNumber];
    viewModel.time = self.lblTime.text;
    
    NSMutableString *caption = [NSMutableString new];
    
    if (self.racer.gender)
        [caption appendString:[self.racer.gender capitalizedString]];
    
    if(self.racer.age != nil)
    {
        if (self.racer.gender)
            [caption appendFormat:@" (%@)", self.racer.age];
        else [caption appendFormat:@"%@", self.racer.age];
    }
    
    viewModel.caption = caption;
    
    return viewModel;
}

@end
