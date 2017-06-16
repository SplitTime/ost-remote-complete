//
//  OSTNetworkManager+Entries.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/15/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager+Entries.h"
#import "CurrentCourse.h"
#import "EntryModel.h"

#define OSTSubmitEventEndpoint @"events/%@/import?data_format=jsonapi_batch"

@implementation OSTNetworkManager (Entries)

- (NSURLSessionDataTask*)submitEntries:(NSArray*)entries completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSMutableArray * entriesArrayDict = [NSMutableArray new];
    
    for (EntryModel * entry in entries)
    {
        [entriesArrayDict addObject:@{@"type": @"live_time",
                                     @"attributes": @{
                                         @"bibNumber": entry.bibNumber,
                                         @"splitId": entry.splitId,
                                         @"subSplitKind": entry.bitKey,
                                         @"absoluteTime": entry.absoluteTime,
                                         @"withPacer": entry.withPacer,
                                         @"stoppedHere": entry.stoppedHere,
                                         @"source": entry.source
                                     }}];
    }
    
    NSString * endpoint = [NSString stringWithFormat:OSTSubmitEventEndpoint,[CurrentCourse getCurrentCourse].eventId];
    
    NSURLSessionDataTask *dataTask = [self POST:endpoint parameters:@{@"data":entriesArrayDict} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
                                      {
                                          onCompletion(responseObject);
                                      } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                          onError(error);
                                      }];
    
    [dataTask resume];
    return dataTask;
}

@end
