//
//  OSTSessionManager.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/14/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTSessionManager.h"
#import "SAMKeychain.h"

#define OSTKeychainService @"OST Session"

@implementation OSTSessionManager

+ (NSString*) getStoredUserName
{
    
    return nil;
}

+ (NSString*) getStoredPassword
{
    return nil;
}

+ (void) setUserName:(NSString*) username andPassword:(NSString*) password
{
    //NSArray * accounts = [SAMKeychain accountsForService:OSTKeychainService];
    
    //First Delete all passwords for previous accounts
    
    /*for (NSString* account in accounts)
    {
        [SAMKeychain deletePasswordForService:OSTKeychainService account:account];
    }
    
    [SAMKeychain setPassword:password forService:OSTKeychainService account:username];*/
}

+ (void) setUserPassword:(NSString*) username
{
    
}

@end
