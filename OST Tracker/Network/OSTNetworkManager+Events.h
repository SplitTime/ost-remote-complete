//
//  OSTNetworkManager+Events.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/14/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager.h"

@interface OSTNetworkManager (Events)

- (NSURLSessionDataTask*)getAllEventsWithCompletionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError;
- (NSURLSessionDataTask*)getEventsDetails:(NSString*)eventId completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError;

@end
