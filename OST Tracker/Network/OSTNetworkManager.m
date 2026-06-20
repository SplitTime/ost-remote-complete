//
//  OSTNetworkManager.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager.h"
#import "JSONResponseSerializerWithData.h"

@implementation OSTNetworkManager

- (id)init
{
    self = [[OSTNetworkManager alloc] initWithBaseURL:[NSURL URLWithString:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_URL"]]];
    
    if (self)
    {
        self.serviceURL = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"BACKEND_URL"];
        self.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        self.securityPolicy.allowInvalidCertificates = YES;
        [self.securityPolicy setValidatesDomainName:NO];
        self.responseSerializer = [JSONResponseSerializerWithData serializer];
        self.requestSerializer = [AFJSONRequestSerializer serializer];
        [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [self.requestSerializer setValue:@"no-cache" forHTTPHeaderField:@"cache-control"];
        [self.requestSerializer setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
        
        [self.requestSerializer setTimeoutInterval:OSTNetworkTimeout];
        
        [self.reachabilityManager startMonitoring];
    }
    
    return self;
}

- (void)addTokenToHeader: (NSString*) token
{
    if (token.length == 0)
    {
        // Clear the header — without the early return this fell through and set a
        // malformed "bearer (null)", which the server then rejected.
        [self.requestSerializer setValue:@"" forHTTPHeaderField:@"Authorization"];
        return;
    }

    [self.requestSerializer setValue:[NSString stringWithFormat:@"bearer %@",token] forHTTPHeaderField:@"Authorization"];
}

@end
