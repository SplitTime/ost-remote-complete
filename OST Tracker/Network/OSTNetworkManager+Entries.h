//
//  OSTNetworkManager+Entries.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/15/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager.h"

@interface OSTNetworkManager (Entries)

- (NSURLSessionDataTask*)submitEntries:(NSArray*)entries completionBlock:(OSTCompletionObjectBlock)onCompletion errorBlock:(OSTErrorBlock)onError;

@end
