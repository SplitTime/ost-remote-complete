//
//  JSONResponseSerializerWithData.h
//  OST
//
//  Created by Luciano on 27/7/16.
//  Copyright (c) 2016. All rights reserved.
//

#import "AFURLResponseSerialization.h"

static NSString * const JSONResponseSerializerWithDataKey = @"JSONResponseSerializerWithDataKey";

@interface JSONResponseSerializerWithData : AFJSONResponseSerializer

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError **)error;

@end
