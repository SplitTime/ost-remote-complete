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
#define OSTSubmitEventGroupEndpoint @"event_groups/%@/import?data_format=jsonapi_batch&limitedResponse=true"
#define OSTGetNotExpectedEndPoint @"event_groups/%@/not_expected?split_name=%@"

@implementation OSTNetworkManager (Entries)

- (NSURLSessionDataTask*)submitEventGroupEntries:(NSArray*)entries useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    return [self submitEntriesToGroup:[CurrentCourse getCurrentCourse].eventGroupId entries:entries useAlternateServer:alternateServer completionBlock:onCompletion errorBlock:onError];
}

- (NSURLSessionDataTask*)submitGroupedEntries:(NSArray*)entries useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSMutableDictionary * groupedEntries = [NSMutableDictionary new];
    
    NSMutableArray * innerEntries;
    for (EntryModel * entry in entries)
    {
        innerEntries = [groupedEntries objectForKey:entry.entryCourseId];
        if (!innerEntries)
            innerEntries = [NSMutableArray new];
        
        [innerEntries addObject:entry];
        
        [groupedEntries setObject:innerEntries forKey:entry.entryCourseId];
    }
    
    return [self submitGroupedInDictionaryEntries:groupedEntries useAlternateServer:alternateServer completionBlock:onCompletion errorBlock:onError];
}

- (NSURLSessionDataTask*)submitGroupedInDictionaryEntries:(NSMutableDictionary*)entries useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    if (entries.allKeys.count == 0)
    {
        onCompletion(nil);
        return nil;
    }
    
    NSString * firstKey = entries.allKeys.firstObject;
    NSLog(@"First Key: %@",firstKey);
    return [self submitEntries:entries[firstKey] toEvent:firstKey useAlternateServer:alternateServer completionBlock:^(id  _Nullable object)
    {
        [entries removeObjectForKey:firstKey];
        [self submitGroupedInDictionaryEntries:entries useAlternateServer:alternateServer completionBlock:onCompletion errorBlock:onError];
    } errorBlock:^(NSError * _Nullable error) {
        onError(error);
    }];
}

- (NSURLSessionDataTask*)submitEntries:(NSArray*)entries toEvent:(NSString*)event useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSMutableArray * entriesArrayDict = [NSMutableArray new];
    
    for (EntryModel * entry in entries)
    {
        [entriesArrayDict addObject:@{@"type": @"live_time",
                                     @"attributes": @{
                                         @"bibNumber": entry.bibNumber,
                                         @"splitId": entry.splitId,
                                         @"subSplitKind": entry.bitKey,
                                         @"enteredTime": entry.absoluteTime,
                                         @"withPacer": entry.withPacer,
                                         @"stoppedHere": entry.stoppedHere,
                                         @"source": entry.source
                                     }}];
    }
    
    NSString * endpoint = [NSString stringWithFormat:OSTSubmitEventEndpoint,event];
    
    if (alternateServer)
    {
        endpoint = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_ALTERNATE_URL"],endpoint];
    }
    
    NSURLSessionDataTask *dataTask = [self POST:endpoint parameters:@{@"uniqueKey": @[@"enteredTime", @"bitkey", @"bibNumber", @"source", @"withPacer", @"stoppedHere"],@"data":entriesArrayDict} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
                                      {
                                          onCompletion(responseObject);
                                      } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                          onError(error);
                                      }];
    
    [dataTask resume];
    return dataTask;
}

- (NSURLSessionDataTask*)submitEntriesToGroup:(NSString*)groupId entries:(NSArray*)entries useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSMutableArray * entriesArrayDict = [NSMutableArray new];
    
    for (EntryModel * entry in entries)
    {
        [entriesArrayDict addObject:@{@"type": @"raw_time",
                                      @"attributes": @{
                                              @"bibNumber": entry.bibNumber,
                                              @"subSplitKind": entry.bitKey,
                                              @"enteredTime": entry.absoluteTime,
                                              @"withPacer": entry.withPacer,
                                              @"stoppedHere": entry.stoppedHere,
                                              @"source": entry.source,
                                              @"splitName": entry.splitName
                                              }}];
    }
    
    NSString * endpoint = [NSString stringWithFormat:OSTSubmitEventGroupEndpoint,groupId];
    
    if (alternateServer)
    {
        endpoint = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_ALTERNATE_URL"],endpoint];
    }
    
    NSURLSessionDataTask *dataTask = [self POST:endpoint parameters:@{@"data":entriesArrayDict} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
                                      {
                                          onCompletion(responseObject);
                                      } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                          onError(error);
                                      }];
    
    [dataTask resume];
    return dataTask;
}

- (NSURLSessionDataTask*)fetchNotExpected:(NSString*)groupId splitName:(NSString*)splitName useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    NSURLSessionDataTask *dataTask = [self autoLoginWithCompletionBlock:^(id object) {
        __block NSString *escapedSplitName = [splitName stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]];
        NSString * endpoint = [NSString stringWithFormat:OSTGetNotExpectedEndPoint,groupId,escapedSplitName];
        
        if (alternateServer)
        {
            endpoint = [NSString stringWithFormat:@"%@%@",[[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_ALTERNATE_URL"],endpoint];
        }
        
        NSURLSessionDataTask *t = [self GET:endpoint parameters:@{} progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject)
                                          {
                                              onCompletion(responseObject);
                                          } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                                              onError(error);
                                          }];
        
        [t resume];
    } errorBlock:^(NSError *error) {
        onError(error);
    }];
    
    [dataTask resume];
    return dataTask;
}

@end
