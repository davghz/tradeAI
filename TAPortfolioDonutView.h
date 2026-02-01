/**
 * TAPortfolioDonutView.h
 */

#import <UIKit/UIKit.h>
@class TAHolding;

@interface TAPortfolioDonutView : UIView
- (void)updateWithHoldings:(NSArray<TAHolding *> *)holdings totalValue:(NSDecimalNumber *)totalValue;
@end

