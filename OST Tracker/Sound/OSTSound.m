//
//  OSTSound.m
//  OST Tracker
//
//  Created by Mariano Donati on 22/10/18.
//  Copyright © 2018 OST. All rights reserved.
//

#import "OSTSound.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

static OSTSound* shared = nil;

@interface OSTSound ()

@property (nonatomic,strong) AVAudioPlayer *currentSound;

@end

@implementation OSTSound

+ (void)initialize {
    shared = [OSTSound new];
}

+ (instancetype)shared {
    return shared;
}

- (void)play:(NSString *)soundName {

    NSString *soundFilePath = [NSString stringWithFormat:@"%@/%@.wav", [[NSBundle mainBundle] resourcePath], soundName];
    NSURL *soundFileURL = [NSURL fileURLWithPath:soundFilePath];
    
    AVAudioPlayer *player = [[AVAudioPlayer alloc] initWithContentsOfURL:soundFileURL error:nil];
    player.numberOfLoops = 0; //Infinite
    
    [player play];
    
    self.currentSound = player;
}

@end
