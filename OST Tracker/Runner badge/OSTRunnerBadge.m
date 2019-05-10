//
//  OSTRunnerBadge.m
//  OST Tracker
//
//  Created by Mariano Donati on 10/05/2019.
//  Copyright © 2019 OST. All rights reserved.
//

#import "OSTRunnerBadge.h"

@interface OSTRunnerBadge()

@property (nonatomic,weak) IBOutlet UILabel *bibNumberLabel;
@property (nonatomic,weak) IBOutlet UILabel *timeLabel;
@property (nonatomic,weak) IBOutlet UILabel *captionLabel;

@end

@implementation OSTRunnerBadge

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame])
    {
        [self load];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder])
    {
        [self load];
    }
    return self;
}

- (void)load
{
    UIView *view = [[[NSBundle bundleForClass:[self class]] loadNibNamed:@"OSTRunnerBadge" owner:self options:nil] firstObject];
    view.frame = self.bounds;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:view];
}

- (void)updateWithModel:(OSTRunnerBadgeViewModel *)viewModel
{
    self.bibNumberLabel.text = viewModel.bibNumber;
    self.timeLabel.text = viewModel.time;
    self.captionLabel.text = viewModel.caption;
}

@end
