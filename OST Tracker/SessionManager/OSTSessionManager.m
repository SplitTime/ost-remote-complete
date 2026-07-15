//
//  OSTSessionManager.m
//  OST Tracker
//
//  Created by Luciano Castro on 6/14/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "OSTSessionManager.h"

@import Security;

#define OSTUserHash @"ba4e70c750190aba2e69821071081060"
#define OSTPasswordHash @"cb592cf34daaac3a853c05d2a4652c6a"

// Service for the generic-password keychain items. No access group, so this works
// on unsigned simulator builds and signed device builds alike. (Replaces the
// dead A0SimpleKeychain pod, which silently failed to persist here — leaving
// autoLogin to read nil credentials and crash.)
#define OSTKeychainService @"com.OpenSplitTime.OST-Remote.credentials"

@implementation OSTSessionManager

+ (NSMutableDictionary *)baseQueryForKey:(NSString *)key
{
    return [@{
        (__bridge id)kSecClass:       (__bridge id)kSecClassGenericPassword,
        (__bridge id)kSecAttrService: OSTKeychainService,
        (__bridge id)kSecAttrAccount: key,
    } mutableCopy];
}

+ (void)setString:(NSString *)value forKey:(NSString *)key
{
    NSMutableDictionary *query = [self baseQueryForKey:key];
    SecItemDelete((__bridge CFDictionaryRef)query); // ensure a single, current item

    OSStatus status = errSecMissingEntitlement;
    if (value.length > 0)
    {
        query[(__bridge id)kSecValueData] = [value dataUsingEncoding:NSUTF8StringEncoding];
        query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAfterFirstUnlock;
        status = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    }

    // Fallback for environments where the keychain is unavailable (unsigned
    // simulator builds have no keychain-access-group entitlement, so SecItemAdd
    // returns errSecMissingEntitlement). Signed device builds use the keychain.
    if (status != errSecSuccess)
    {
        [self setFallbackString:value forKey:key];
    }
    else
    {
        [self setFallbackString:nil forKey:key]; // keychain is source of truth
    }
}

+ (NSString *)stringForKey:(NSString *)key
{
    NSMutableDictionary *query = [self baseQueryForKey:key];
    query[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    query[(__bridge id)kSecMatchLimit] = (__bridge id)kSecMatchLimitOne;

    CFTypeRef result = NULL;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &result);
    if (status == errSecSuccess && result != NULL)
    {
        NSData *data = (__bridge_transfer NSData *)result;
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    }
    return [self fallbackStringForKey:key];
}

// MARK: - Sandbox-file fallback (Application Support, not synced/backed up issues aside)

+ (NSURL *)fallbackStoreURL
{
    NSURL *dir = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    [[NSFileManager defaultManager] createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir URLByAppendingPathComponent:@"ost_credentials.plist"];
}

+ (void)setFallbackString:(NSString *)value forKey:(NSString *)key
{
    NSURL *url = [self fallbackStoreURL];
    NSMutableDictionary *store = [[NSDictionary dictionaryWithContentsOfURL:url] mutableCopy] ?: [NSMutableDictionary new];
    if (value.length > 0) { store[key] = value; } else { [store removeObjectForKey:key]; }
    [store writeToURL:url atomically:YES];
}

+ (NSString *)fallbackStringForKey:(NSString *)key
{
    return [[NSDictionary dictionaryWithContentsOfURL:[self fallbackStoreURL]] objectForKey:key];
}

+ (NSString*) getStoredUserName
{
    return [self stringForKey:OSTUserHash];
}

+ (NSString*) getStoredPassword
{
    return [self stringForKey:OSTPasswordHash];
}

+ (void) setUserName:(NSString*) username andPassword:(NSString*) password
{
    [self setString:username forKey:OSTUserHash];
    [self setString:password forKey:OSTPasswordHash];
}

+ (NSString *) getUUIDString
{
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"UUID"])
    {
        [[NSUserDefaults standardUserDefaults] setObject:[[NSUUID UUID] UUIDString] forKey:@"UUID"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }

    return [[NSUserDefaults standardUserDefaults] objectForKey:@"UUID"];
}

@end
