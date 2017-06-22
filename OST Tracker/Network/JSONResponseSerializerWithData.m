//
//  JSONResponseSerializerWithData.h
//  OST
//
//  Created by Luciano on 27/7/16.
//  Copyright (c) 2017. All rights reserved.
//

#import "JSONResponseSerializerWithData.h"
#import "AppDelegate.h"

@implementation JSONResponseSerializerWithData

- (id)responseObjectForResponse:(NSURLResponse *)response
                           data:(NSData *)data
                          error:(NSError **)error
{
    id JSONObject = [super responseObjectForResponse:response data:data error:error];
    
    if (*error != nil) {
        NSMutableDictionary *userInfo = [(*error).userInfo mutableCopy];
        if (data == nil) {
            //			// NOTE: You might want to convert data to a string here too, up to you.
            //userInfo[JSONResponseSerializerWithDataKey] = @"";
            userInfo[JSONResponseSerializerWithDataKey] = nil;
        } else {
            //			// NOTE: You might want to convert data to a string here too, up to you.
            if ([data isKindOfClass:[NSData class]]) {
                userInfo[JSONResponseSerializerWithDataKey] = [[NSString alloc] initWithData:data
                                                                                    encoding:NSUTF8StringEncoding];
            } else {
                userInfo[JSONResponseSerializerWithDataKey] = data;
            }
            
            NSError * jsonError = nil;
            
            if ([response class] == [NSHTTPURLResponse class])
            {
                NSHTTPURLResponse * httpresponse = (NSHTTPURLResponse*)response;
                
                if ([[[httpresponse allHeaderFields] objectForKey:@"Content-Type"] isEqualToString:@"application/json"])
                {
                    userInfo[JSONResponseSerializerWithDataKey] = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&jsonError];
                }
            }
            
            
        }
        NSError *newError = [NSError errorWithDomain:(*error).domain code:(*error).code userInfo:userInfo];
        (*error) = newError;
    }
    
    return (JSONObject);
}

-(void)logout
{
    //[[AppDelegate currentInstance] logOutAction];
}

@end
