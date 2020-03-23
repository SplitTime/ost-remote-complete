//
//  OSTAboutViewController.m
//  OST Tracker
//
//  Created by Guillermo Apoj on 3/22/20.
//  Copyright © 2020 OST. All rights reserved.
//

#import "OSTAboutViewController.h"
#import "AppDelegate.h"
#import "UIView+Additions.h"

@interface OSTAboutViewController ()
@property (weak, nonatomic) IBOutlet UILabel *lblTitle;
@property (weak, nonatomic) IBOutlet UILabel *targetLbl;
@property (weak, nonatomic) IBOutlet UILabel *versionLbl;
@property (weak, nonatomic) IBOutlet UILabel *primaryLbl;
@property (weak, nonatomic) IBOutlet UILabel *fallBackLbl;

@end

@implementation OSTAboutViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    self.targetLbl.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"];
    self.versionLbl.text = [NSString stringWithFormat:@"Version: %@",[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]];
//    if(  [[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleName"] isEqualToString:@"OST Remote Dev"]){
        self.primaryLbl.text =  [NSString stringWithFormat: @"Primary: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_URL"]  ];
        self.fallBackLbl.text = [NSString stringWithFormat: @"Fallback: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_ALTERNATE_URL"]  ];
//    }else{
//        self.primaryLbl.text =  @"Primary: https://www.opensplittime.org";
//               self.fallBackLbl.text = [NSString stringWithFormat: @"Fallback: %@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_ALTERNATE_URL"]  ];
//    }
   if (IS_IPHONE_X || IS_IPHONE_XR)
    {
        self.lblTitle.numberOfLines = 1;
        self.lblTitle.bottom = self.lblTitle.bottom + 7;
        self.menuButton.bottom = self.menuButton.bottom + 7;
    }
      
}

 - (IBAction)onMenu:(id)sender
{
    [[AppDelegate getInstance].rightMenuVC toggleRightSideMenuCompletion:nil];
}
@end
