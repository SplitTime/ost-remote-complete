//
//  OSTNetworkManager+Login.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/13/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager+Login.h"
#import "OSTSessionManager.h"
// OSTAuthBridge (Swift) performs the login POST through APIClient.
#if __has_include("OST_Remote-Swift.h")
#import "OST_Remote-Swift.h"
#elif __has_include("OST_Remote_Dev-Swift.h")
#import "OST_Remote_Dev-Swift.h"
#endif

@implementation OSTNetworkManager (Login)

- (NSURLSessionDataTask*)loginWithEmail:(NSString*)email password:(NSString*)password completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    // Guard against missing credentials: building the params dictionary with a
    // nil value throws and crashes (e.g. autoLogin when nothing is stored).
    if (email.length == 0 || password.length == 0)
    {
        if (onError)
        {
            onError([NSError errorWithDomain:@"OST" code:401
                                    userInfo:@{NSLocalizedDescriptionKey: @"Missing stored credentials. Please log in again."}]);
        }
        return nil;
    }

    // Perform the login POST through the Swift APIClient. AFNetworking's form
    // encoding of the credentials was being rejected by the server ("Invalid email
    // or password") on autoLogin even for valid stored creds — the same creds that
    // logged in fine via APIClient. Callers consume object[@"token"].
    [OSTAuthBridge loginWithEmail:email password:password completion:^(NSString *token, NSError *error) {
        if (token.length)
        {
            onCompletion(@{@"token": token});
        }
        else if (onError)
        {
            onError(error ?: [NSError errorWithDomain:@"OST" code:401
                                             userInfo:@{NSLocalizedDescriptionKey: @"Login failed"}]);
        }
    }];
    return nil;
}

- (NSURLSessionDataTask*)autoLoginWithCompletionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    return [self loginWithEmail:[OSTSessionManager getStoredUserName] password:[OSTSessionManager getStoredPassword] completionBlock:^(id object) {
            [[AppDelegate getInstance].getNetworkManager addTokenToHeader:object[@"token"]];
            onCompletion(object);
    } errorBlock:^(NSError *error) {
        onError(error);
    }];
}

@end
