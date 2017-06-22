//
//  NSError+OSTErrors.h
//  OST
//
//  Created by Luciano Castro on 11/10/16.
//  Copyright © 2016 OST. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSError (OSTErrors)

- (NSDictionary*) errors;
- (NSString*) errorsFromDictionary;

@end
