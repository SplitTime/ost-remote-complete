//
//  OSTNetworkManager.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTNetworkManager.h"

#define OSTServiceURL   @"https://ost-stage.herokuapp.com/api/v1/"

@implementation OSTNetworkManager

- (id)init
{
    NSString * servicesURL   = OSTServiceURL;
    self = [[OSTNetworkManager alloc] initWithBaseURL:[NSURL URLWithString:servicesURL]];
    
    if (self)
    {
        self.serviceURL = servicesURL;
        self.securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeNone];
        //self.responseSerializer = [JSONResponseSerializerWithData serializer];
        self.requestSerializer = [AFJSONRequestSerializer serializer];
        [self.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        
        [self.requestSerializer setTimeoutInterval:OSTNetworkTimeout];
        
        [self.reachabilityManager startMonitoring];
    }
    
    return self;
}

- (void)addTokenToHeader: (NSString*) token
{
    if(token.length == 0)
        return;
    
    [self.requestSerializer setValue:[NSString stringWithFormat:@"bearer %@",token] forHTTPHeaderField:@"Authorization"];
}

@end
