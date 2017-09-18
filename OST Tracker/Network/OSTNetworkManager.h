//
//  OSTNetworkManager.h
//  OST Tracker
//
//  Created by Luciano Castro on 6/12/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "AFHTTPSessionManager.h"
#import "AFNetworking.h"

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

@interface OSTNetworkManager : AFHTTPSessionManager

@property (nonatomic,strong) NSString * _Nullable serviceURL;
@property (nonatomic,unsafe_unretained) BOOL usingAlternateUrl;

- (void) addTokenToHeader: (NSString*_Nullable) token;
- (id _Nullable ) initWithNetworkUrl:(NSString*_Nullable) url;

@end
