//
//  OSTSessionManager.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/14/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OSTSessionManager : NSObject

+ (NSString*) getStoredUserName;
+ (NSString*) getStoredPassword;
+ (void) setUserName:(NSString*) username andPassword:(NSString*) password;
+ (NSString *) getUUIDString;

@end
