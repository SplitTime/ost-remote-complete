//
//  OSTNetworkManager+Entries.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/15/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager.h"

@interface OSTNetworkManager (Entries)

- (NSURLSessionDataTask*)submitEntries:(NSArray*)entries toEvent:(NSString*)event useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError;

- (NSURLSessionDataTask*)submitGroupedEntries:(NSArray*)entries useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError;

- (NSURLSessionDataTask*)submitEventGroupEntries:(NSArray*)entries useAlternateServer:(BOOL)alternateServer completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError;

@end
