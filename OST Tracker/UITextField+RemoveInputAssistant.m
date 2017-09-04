//
//  UILabel+RemoveInputAssistant.m
//  OST Tracker
//
//  Created by Luciano Castro on 9/4/17.
//  Copyright © 2017 OST. All rights reserved.
//

#import "UITextField+RemoveInputAssistant.h"

@implementation UITextField (RemoveInputAssistant)

- (void) removeInputAssistant
{
    UITextInputAssistantItem* item = [self inputAssistantItem];
    item.leadingBarButtonGroups = @[];
    item.trailingBarButtonGroups = @[];
}

@end
