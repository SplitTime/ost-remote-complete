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
// OSTBackend (Swift) submits over URLSession.

#define OSTSubmitEventGroupEndpoint @"event_groups/%@/import?data_format=jsonapi_batch&limitedResponse=true"

@implementation OSTNetworkManager (Entries)

- (NSURLSessionDataTask*)submitEventGroupEntries:(NSArray*)entries useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError
{
    return [self submitEntriesToGroup:[CurrentCourse getCurrentCourse].eventGroupId entries:entries useAlternateServer:alternateServer completionBlock:onCompletion errorBlock:onError];
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
    NSString * base = [[NSBundle mainBundle] objectForInfoDictionaryKey:(alternateServer ? @"BACKEND_ALTERNATE_URL" : @"BACKEND_URL")];
    NSString * fullURL = [NSString stringWithFormat:@"%@%@", base, endpoint];
    NSString * auth = self.authToken.length ? [NSString stringWithFormat:@"bearer %@", self.authToken] : nil;

    // Submit over URLSession (OSTBackend) — the payload is the legacy jsonapi_batch shape.
    [OSTBackend postJSONToURL:fullURL authorization:auth body:@{@"data":entriesArrayDict} completion:^(id object, NSError *error)
    {
        if (error) { onError(error); } else { onCompletion(object); }
    }];

    return nil;
}

@end
