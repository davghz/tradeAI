/**
 * TAGlassCardView.mm
 */

#import "TAGlassCardView.h"

@interface TAGlassCardView ()
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) CAGradientLayer *sheenLayer;
@end

@implementation TAGlassCardView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.25];
        self.layer.cornerRadius = 16.0;
        self.layer.borderWidth = 1.0;
        self.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
        self.clipsToBounds = YES;

        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
        self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        self.blurView.alpha = 0.7;
        [self addSubview:self.blurView];

        self.sheenLayer = [CAGradientLayer layer];
        self.sheenLayer.colors = @[
            (id)[UIColor colorWithWhite:1.0 alpha:0.18].CGColor,
            (id)[UIColor colorWithWhite:1.0 alpha:0.03].CGColor
        ];
        self.sheenLayer.startPoint = CGPointMake(0, 0);
        self.sheenLayer.endPoint = CGPointMake(1, 1);
        [self.blurView.contentView.layer addSublayer:self.sheenLayer];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    self.blurView.frame = self.bounds;
    self.sheenLayer.frame = self.bounds;
}

@end

