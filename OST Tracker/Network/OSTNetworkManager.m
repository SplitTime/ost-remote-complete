//
//  OSTNetworkManager.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager.h"

@implementation OSTNetworkManager

- (id)init
{
    self = [super init];
    if (self)
    {
        self.serviceURL = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_URL"];
    }
    return self;
}

- (void)addTokenToHeader:(NSString*)token
{
    self.authToken = token.length ? token : nil;
}

@end
