//
//  OSTNetworkManager+Login.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/13/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager+Login.h"
#import "OSTSessionManager.h"
#import "OSTLoginViewController.h"

#define OSTLoginEndpoint @"auth"

@implementation OSTNetworkManager (Login)

- (NSURLSessionDataTask*)loginWithEmail:(NSString*)email password:(NSString*)password completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    self.requestSerializer = [AFHTTPRequestSerializer serializer];
    [self.requestSerializer setValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];
    
    [self.requestSerializer setValue:@"no-cache" forHTTPHeaderField:@"cache-control"];
    [self.requestSerializer setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    
    NSDictionary * params = @{@"user[email]":email,@"user[password]":password};
    
    NSURLSessionDataTask *dataTask = [self POST:OSTLoginEndpoint parameters:params progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
    {
        self.requestSerializer = [AFJSONRequestSerializer serializer];
        [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [self.requestSerializer setValue:@"no-cache" forHTTPHeaderField:@"cache-control"];
        [self.requestSerializer setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        onCompletion(responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        self.requestSerializer = [AFJSONRequestSerializer serializer];
        [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [self.requestSerializer setValue:@"no-cache" forHTTPHeaderField:@"cache-control"];
        [self.requestSerializer setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        onError(error);
    }];
    
    [dataTask resume];
    return dataTask;
}

- (NSURLSessionDataTask*)autoLoginWithCompletionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    return [self loginWithEmail:[OSTSessionManager getStoredUserName] password:[OSTSessionManager getStoredPassword] completionBlock:^(id object) {
            [[AppDelegate getInstance].getNetworkManager addTokenToHeader:object[@"token"]];
            onCompletion(object);
    } errorBlock:^(NSError *error) {
        if([[error errorsFromDictionary] containsString:@" errors: Invalid email or password"])
        {
            UIViewController *topController = [UIApplication sharedApplication].keyWindow.rootViewController;
            
            while (topController.presentedViewController) {
                topController = topController.presentedViewController;
            }

            OSTLoginViewController * loginVC = [[OSTLoginViewController alloc] initWithNibName:nil bundle:nil];
            [topController presentViewController:loginVC animated:YES completion:nil];
            loginVC.completionBlock = onCompletion;
        }
        else
        {
            onError(error);
        }
    }];
}

@end
