//
//  OSTSessionManager.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/14/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTSessionManager.h"

#import <SimpleKeychain/SimpleKeychain.h>

#define OSTUserHash @"ba4e70c750190aba2e69821071081060"
#define OSTPasswordHash @"cb592cf34daaac3a853c05d2a4652c6a"

#define OSTKeychainService @"com.OST.OST-Remote"

@implementation OSTSessionManager

+ (NSString*) getStoredUserName
{
    return [[A0SimpleKeychain keychain] stringForKey:OSTUserHash];
}

+ (NSString*) getStoredPassword
{
    return [[A0SimpleKeychain keychain] stringForKey:OSTPasswordHash];
}

+ (void) setUserName:(NSString*) username andPassword:(NSString*) password
{
    [[A0SimpleKeychain keychain] setString:username forKey:OSTUserHash];
    [[A0SimpleKeychain keychain] setString:password forKey:OSTPasswordHash];
}

+ (NSString *) getUUIDString
{
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"UUID"])
    {
        [[NSUserDefaults standardUserDefaults] setObject:[[NSUUID UUID] UUIDString] forKey:@"UUID"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    return [[NSUserDefaults standardUserDefaults] objectForKey:@"UUID"];
}

@end
