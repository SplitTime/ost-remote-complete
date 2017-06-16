//
//  OSTNetworkManager+Login.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/13/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager.h"

@interface OSTNetworkManager (Login)

- (NSURLSessionDataTask*)loginWithEmail:(NSString*)email password:(NSString*)password completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError;

- (NSURLSessionDataTask*)autoLoginWithCompletionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError;

@end
