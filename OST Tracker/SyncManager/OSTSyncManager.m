//
//  OSTSyncManager.m
//  OST Tracker
//
//  Created by Mariano Donati on 22/10/18.
//  Copyright © 2018 OST. All rights reserved.
//

#import "OSTSyncManager.h"

static OSTSyncManager *shared = nil;

@implementation OSTSyncManager

+ (void)initialize
{
    shared = [OSTSyncManager new];
}

+ (instancetype)shared
{
    return shared;
}



@end
