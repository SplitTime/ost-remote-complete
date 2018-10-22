//
//  OSTSound.h
//  OST Tracker
//
//  Created by Mariano Donati on 22/10/18.
//  Copyright © 2018 OST. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSTSound : NSObject

+ (instancetype)shared;
- (void)play:(NSString *)soundName;

@end

NS_ASSUME_NONNULL_END
