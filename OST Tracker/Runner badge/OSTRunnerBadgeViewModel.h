//
//  OSTRunnerBadgeViewModel.h
//  OST Tracker
//
//  Created by Mariano Donati on 10/05/2019.
//  Copyright © 2019 OST. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OSTRunnerBadgeViewModel : NSObject

@property (nonatomic,strong) NSString *bibNumber;
@property (nonatomic,strong) NSString *time;
@property (nonatomic,strong) NSString *caption;
@property (nonatomic) BOOL withPacer;
@property (nonatomic) BOOL dropping;

@end

NS_ASSUME_NONNULL_END
