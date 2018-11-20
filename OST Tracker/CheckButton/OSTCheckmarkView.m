//
//  OSTCheckmarkView.m
//  OST Tracker
//
//  Created by Mariano Donati on 20/11/18.
//  Copyright © 2018 OST. All rights reserved.
//

#import "OSTCheckmarkView.h"
#import "UIView+Additions.h"

@interface OSTCheckmarkView ()

@property (nonatomic,weak) IBOutlet UIImageView *checkmark;
@property (nonatomic,weak) IBOutlet UIView *circle;
@property (nonatomic,weak) IBOutlet UILabel *label;

@end

@implementation OSTCheckmarkView

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
    UIView *view = [[[NSBundle bundleForClass:[self class]] loadNibNamed:@"OSTCheckmarkView" owner:self options:nil] firstObject];
    view.frame = self.bounds;
    view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self addSubview:view];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTap)];
    [self addGestureRecognizer:tap];
}

- (void)onTap
{
    if (self.selected) {
        return;
    }
    
    self.selected = YES;
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    self.circle.cornerRadius = self.circle.width / 2;
}

- (UIColor *)color
{
    return self.circle.borderColor;
}

- (void)setColor:(UIColor *)color
{
    self.circle.borderColor = color;
    self.label.textColor = color;
}

- (NSString *)text
{
    return self.label.text;
}

- (void)setText:(NSString *)text
{
    self.label.text = text;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    if (selected)
    {
        self.checkmark.hidden = NO;
        self.circle.backgroundColor = self.circle.borderColor;
    }
    else
    {
        self.checkmark.hidden = YES;
        self.circle.backgroundColor = [UIColor clearColor];
    }
}

@end
