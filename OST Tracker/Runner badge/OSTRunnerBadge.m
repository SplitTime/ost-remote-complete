//
//  OSTRunnerBadge.m
//  OST Tracker
//
//  Created by Mariano Donati on 10/05/2019.
//  Copyright © 2019 OST. All rights reserved.
//

#import "OSTRunnerBadge.h"
#import "UIView+Additions.h"

@interface OSTRunnerBadge()

@property (nonatomic,weak) IBOutlet UILabel *bibNumberLabel;
@property (nonatomic,weak) IBOutlet UILabel *timeLabel;
@property (nonatomic,weak) IBOutlet UILabel *captionLabel;
@property (nonatomic,weak) IBOutlet UIView *containerView;
@property (nonatomic,weak) IBOutlet UILabel *calloutLabel;

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

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self adjustFontSizes];
}

- (void)setFrame:(CGRect)frame
{
    [super setFrame:frame];
    [self adjustFontSizes];
}

- (void)updateWithModel:(OSTRunnerBadgeViewModel *)viewModel
{
    self.bibNumberLabel.text = viewModel.bibNumber;
    self.timeLabel.text = viewModel.time;
    self.captionLabel.text = viewModel.caption;
}

- (void)adjustFontSizes
{
    if (self.timeLabel.font == nil) {
        return;
    }
    
    CGFloat primaryScale = 0.62;
    CGFloat secondaryScale = 0.23;
    
    CGFloat primaryFontSize = self.containerView.height * primaryScale;
    CGFloat secondaryFontSize = self.containerView.height * secondaryScale;
    
    self.timeLabel.font = [self.timeLabel.font fontWithSize:primaryFontSize];
    self.bibNumberLabel.font = [self.bibNumberLabel.font fontWithSize:primaryFontSize];
    self.captionLabel.font = [self.captionLabel.font fontWithSize:primaryFontSize];
    self.calloutLabel.font = [self.calloutLabel.font fontWithSize:secondaryFontSize];
}

@end
