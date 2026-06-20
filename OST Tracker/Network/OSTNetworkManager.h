//
//  OSTNetworkManager.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//
//  No longer an AFHTTPSessionManager — all requests now run through the Swift
//  APIClient/OSTBackend. This class is reduced to the shared auth-token holder
//  (set after login, read by the submit) plus native reachability.
//

#import <Foundation/Foundation.h>

typedef void (^VoidBlock)(void);
typedef void (^OSTCompletionNumberBlock)(NSNumber* _Nullable number);
typedef void (^OSTCompletionArrayBlock)(NSArray* _Nullable records);
typedef void (^OSTCompletionDictionaryBlock)(NSDictionary* _Nullable records);
typedef void (^OSTCompletionObjectBlock)(id _Nullable object);
typedef void (^OSTProgressBlock)(NSProgress * _Nonnull uploadProgress);
typedef void (^OSTErrorBlock)(NSError* _Nullable error);

@protocol OSTManagedObjectUpdateKeys

+ (NSString*_Nullable)recordsKey;
+ (NSString*_Nullable)uniqueId;
+ (NSString*_Nullable)remoteUniqueId;

@end

@protocol OSTUnManagedObjectUpdateKeys

+ (NSString*_Nullable)recordsKey;
+ (NSString*_Nullable)uniqueId;
+ (NSString*_Nullable)remoteUniqueId;
+ (NSDictionary*_Nullable)mapping;

@end

@interface OSTNetworkManager : NSObject

@property (nonatomic,strong) NSString * _Nullable serviceURL;
/// Raw bearer token from the last login; the submit reads it via the request.
@property (nonatomic,copy) NSString * _Nullable authToken;
@property (nonatomic,readonly) BOOL isReachable;

- (void)addTokenToHeader: (NSString*_Nullable) token;
- (void)startMonitoring;

@end
