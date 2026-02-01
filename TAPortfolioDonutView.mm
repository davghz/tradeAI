/**
 * TAPortfolioDonutView.mm
 */

#import "TAPortfolioDonutView.h"
#import "TAPortfolio.h"

@interface TAPortfolioDonutView ()
@property (nonatomic, copy) NSArray<TAHolding *> *holdings;
@property (nonatomic, strong) NSDecimalNumber *totalValue;
@property (nonatomic, strong) NSArray<UIColor *> *palette;
@end

@implementation TAPortfolioDonutView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        _holdings = @[];
        _totalValue = [NSDecimalNumber zero];
        _palette = @[
            [UIColor colorWithRed:0.2 green:0.9 blue:0.7 alpha:1.0],
            [UIColor colorWithRed:0.0 green:0.7 blue:0.3 alpha:1.0],
            [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0],
            [UIColor colorWithRed:0.95 green:0.7 blue:0.2 alpha:1.0],
            [UIColor colorWithRed:0.8 green:0.2 blue:0.9 alpha:1.0],
            [UIColor colorWithRed:1.0 green:0.3 blue:0.8 alpha:1.0]
        ];
    }
    return self;
}

- (void)updateWithHoldings:(NSArray<TAHolding *> *)holdings totalValue:(NSDecimalNumber *)totalValue {
    self.holdings = holdings ?: @[];
    self.totalValue = totalValue ?: [NSDecimalNumber zero];
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return;
    }

    CGRect inset = CGRectInset(rect, 6, 6);
    CGFloat radius = MIN(inset.size.width, inset.size.height) * 0.5;
    CGPoint center = CGPointMake(CGRectGetMidX(inset), CGRectGetMidY(inset));
    CGFloat innerRadius = radius * 0.62;

    NSDecimalNumber *total = self.totalValue;
    if (self.holdings.count == 0 || [total compare:[NSDecimalNumber zero]] != NSOrderedDescending) {
        NSDictionary *attrs = @{
            NSFontAttributeName: [UIFont systemFontOfSize:12],
            NSForegroundColorAttributeName: [UIColor colorWithWhite:0.6 alpha:1.0]
        };
        NSString *text = @"No portfolio data";
        CGSize size = [text sizeWithAttributes:attrs];
        [text drawAtPoint:CGPointMake(center.x - size.width * 0.5, center.y - size.height * 0.5)
           withAttributes:attrs];
        return;
    }

    CGFloat startAngle = (CGFloat)-M_PI_2;
    NSInteger index = 0;
    for (TAHolding *holding in self.holdings) {
        NSDecimalNumber *value = [holding value];
        if ([value compare:[NSDecimalNumber zero]] != NSOrderedDescending) {
            index++;
            continue;
        }
        double fraction = value.doubleValue / total.doubleValue;
        CGFloat sweep = (CGFloat)(fraction * M_PI * 2.0);
        UIColor *color = self.palette[index % self.palette.count];

        CGContextMoveToPoint(context, center.x, center.y);
        CGContextAddArc(context, center.x, center.y, radius, startAngle, startAngle + sweep, 0);
        CGContextAddArc(context, center.x, center.y, innerRadius, startAngle + sweep, startAngle, 1);
        CGContextClosePath(context);
        CGContextSetFillColorWithColor(context, color.CGColor);
        CGContextFillPath(context);

        startAngle += sweep;
        index++;
    }

    // Inner circle shading
    CGContextSetFillColorWithColor(context, [UIColor colorWithWhite:0.05 alpha:0.9].CGColor);
    CGContextAddArc(context, center.x, center.y, innerRadius - 1.5, 0, (CGFloat)M_PI * 2.0, 0);
    CGContextFillPath(context);
}

@end

