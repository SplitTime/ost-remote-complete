//
//  OSTNetworkManager.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager.h"
// Generated Swift header — for OSTReachability. Module name differs per target.
#if __has_include("OST_Remote-Swift.h")
#import "OST_Remote-Swift.h"
#elif __has_include("OST_Remote_Dev-Swift.h")
#import "OST_Remote_Dev-Swift.h"
#endif

@implementation OSTNetworkManager

- (id)init
{
    self = [super init];
    if (self)
    {
        self.serviceURL = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_URL"];
        [self startMonitoring];
    }
    return self;
}

- (void)addTokenToHeader:(NSString*)token
{
    self.authToken = token.length ? token : nil;
}

- (void)startMonitoring
{
    [[OSTReachability shared] start];
}

- (BOOL)isReachable
{
    return [OSTReachability shared].isReachable;
}

@end
