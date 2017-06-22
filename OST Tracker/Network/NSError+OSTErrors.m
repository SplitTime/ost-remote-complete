//
//  NSError+OSTErrors.m
//  OST
//
//  Created by Luciano Castro on 11/10/16.
//  Copyright © 2016 OST. All rights reserved.
//

#import "NSError+OSTErrors.h"

static NSString * const JSONResponseSerializerWithDataKey = @"JSONResponseSerializerWithDataKey";

@implementation NSError (OSTErrors)

- (NSDictionary*) errors
{
    if (self.userInfo && [self.userInfo isKindOfClass:[NSDictionary class]] && [self.userInfo[JSONResponseSerializerWithDataKey] isKindOfClass:[NSDictionary class]])
        return ((NSDictionary*)(self.userInfo[JSONResponseSerializerWithDataKey]))[@"errors"];
    else return nil;
}

- (NSString*) errorsFromDictionary
{
    NSString * returnString = [[NSString alloc] initWithData:[self userInfo][@"com.alamofire.serialization.response.error.data" ] encoding:NSUTF8StringEncoding];
    
    returnString = [returnString stringByReplacingOccurrencesOfString:@"[" withString:@" "];
    returnString = [returnString stringByReplacingOccurrencesOfString:@"]" withString:@" "];
    returnString = [returnString stringByReplacingOccurrencesOfString:@"{" withString:@" "];
    returnString = [returnString stringByReplacingOccurrencesOfString:@"}" withString:@" "];
    returnString = [returnString stringByReplacingOccurrencesOfString:@"\"" withString:@""];
    return returnString;
}

@end
