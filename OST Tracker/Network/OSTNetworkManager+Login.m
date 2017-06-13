//
//  OSTNetworkManager+Login.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/13/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager+Login.h"

#define OSTLoginEndpoint @"auth"

@implementation OSTNetworkManager (Login)

- (NSURLSessionDataTask*)loginWithEmail:(NSString*)email password:(NSString*)password completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSURLSessionDataTask *dataTask = [self POST:[NSString stringWithFormat:@"%@?user[email]=%@&user[password]=%@",OSTLoginEndpoint, email, password] parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        onCompletion(responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        onError(error);
    }];
    
    [dataTask resume];
    return dataTask;
}

@end
