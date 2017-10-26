//
//  OSTNetworkManager+Events.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/14/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager+Events.h"

#define OSTEventsEndpoint @"event_groups?filter[editable]=true&filter[availableLive]=true"
#define OSTEventDetailsEndpoint @"event_groups/%@?include=events.efforts"
#define OSTEventGroupEndpoint @"event_groups/%@?include=events.efforts,events.splits"

@implementation OSTNetworkManager (Events)

- (NSURLSessionDataTask*)getAllEventsWithCompletionBlock:(OSTCompletionObjectBlock)onCompletion progressBlock:(OSTProgressBlock)onProgress errorBlock:(OSTErrorBlock)onError
{
    NSURLSessionDataTask *dataTask = [self GET:OSTEventsEndpoint parameters:nil progress:onProgress success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
    {
      onCompletion(responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
      onError(error);
    }];
    
    [dataTask resume];
    return dataTask;
}

- (NSURLSessionDataTask*)getEventsDetails:(NSString*)eventId completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSURLSessionDataTask *dataTask = [self autoLoginWithCompletionBlock:^(id object) {
        [self GET:[NSString stringWithFormat:OSTEventDetailsEndpoint,eventId] parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
                                          {
                                              onCompletion(responseObject);
                                          } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                              onError(error);
                                          }];
    } errorBlock:^(NSError *error) {
        onError(error);
    }];
    
    [dataTask resume];
    return dataTask;
}

- (NSURLSessionDataTask*)getEventGroup:(NSString*)eventId completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSURLSessionDataTask *dataTask = [self autoLoginWithCompletionBlock:^(id object) {
        [self GET:[NSString stringWithFormat:OSTEventGroupEndpoint,eventId] parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
         {
             onCompletion(responseObject);
         } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
             onError(error);
         }];
    } errorBlock:^(NSError *error) {
        onError(error);
    }];
    
    [dataTask resume];
    return dataTask;
}

@end
