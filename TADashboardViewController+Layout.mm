/**
 * TADashboardViewController+Layout.mm
 */

#import "TADashboardViewController+Private.h"

@implementation TADashboardViewController (Layout)

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    self.scrollView.frame = self.view.bounds;
    self.gradientLayer.frame = self.view.bounds;

    CGFloat width = self.view.bounds.size.width;
    CGFloat margin = 20;
    CGFloat y = 12;

    self.titleLabel.frame = CGRectMake(margin, y, width - (margin * 2), 18);
    y += 20;

    self.authLabel.frame = CGRectMake(margin, y, width - (margin * 2), 14);
    y += 16;
    self.modelLabel.frame = CGRectMake(margin, y, width - (margin * 2), 14);
    y += 20;

    self.priceCard.frame = CGRectMake(margin, y, width - (margin * 2), 168);
    CGFloat cardPadding = 14;
    self.symbolButton.frame = CGRectMake(cardPadding, 12, 160, 28);
    self.priceLabel.frame = CGRectMake(cardPadding, 48, width - (margin * 2) - (cardPadding * 2), 46);
    self.changeLabel.frame = CGRectMake(cardPadding, 98, width - (margin * 2) - (cardPadding * 2), 18);
    self.bidAskLabel.frame = CGRectMake(cardPadding, 118, width - (margin * 2) - (cardPadding * 2), 18);
    self.statsLabel.frame = CGRectMake(cardPadding, 136, width - (margin * 2) - (cardPadding * 2), 16);
    y += 184;

    self.chartCard.frame = CGRectMake(margin, y, width - (margin * 2), 248);
    self.timeframeControl.frame = CGRectMake(cardPadding, 12, width - (margin * 2) - (cardPadding * 2), 36);
    self.chartView.frame = CGRectMake(cardPadding, 58, width - (margin * 2) - (cardPadding * 2), 170);
    y += 264;

    self.performanceCard.frame = CGRectMake(margin, y, width - (margin * 2), 150);
    self.performanceAccentView.frame = CGRectMake(cardPadding, 14, 4, 20);
    self.performanceIconView.frame = CGRectMake(cardPadding + 10, 10, 20, 20);
    self.performanceTitleLabel.frame = CGRectMake(cardPadding + 36, 12, width - (margin * 2) - (cardPadding * 2) - 36, 20);
    self.performanceChangeLabel.frame = CGRectMake(cardPadding, 44, width - (margin * 2) - (cardPadding * 2), 16);
    self.performanceRangeLabel.frame = CGRectMake(cardPadding, 64, width - (margin * 2) - (cardPadding * 2), 16);
    self.performanceVolLabel.frame = CGRectMake(cardPadding, 84, width - (margin * 2) - (cardPadding * 2), 16);
    self.performanceMomentumLabel.frame = CGRectMake(cardPadding, 104, width - (margin * 2) - (cardPadding * 2), 16);
    self.performanceMomentumBar.frame = CGRectMake(cardPadding, 124, width - (margin * 2) - (cardPadding * 2), 6);
    y += 166;

    self.portfolioCard.frame = CGRectMake(margin, y, width - (margin * 2), 190);
    self.balanceLabel.frame = CGRectMake(cardPadding, 14, width - (margin * 2) - (cardPadding * 2), 24);
    self.portfolioHoldingsLabel.frame = CGRectMake(cardPadding, 44, width - (margin * 2) - (cardPadding * 2), 120);
    y += 206;

    self.riskCard.frame = CGRectMake(margin, y, width - (margin * 2), 150);
    self.riskTitleLabel.frame = CGRectMake(cardPadding, 12, width - (margin * 2) - (cardPadding * 2) - 60, 20);
    [self.riskEnabledSwitch sizeToFit];
    CGRect riskSwitchFrame = self.riskEnabledSwitch.frame;
    self.riskEnabledSwitch.frame = CGRectMake(self.riskCard.bounds.size.width - cardPadding - riskSwitchFrame.size.width,
                                              6,
                                              riskSwitchFrame.size.width,
                                              riskSwitchFrame.size.height);
    self.riskStopLabel.frame = CGRectMake(cardPadding, 44, width - (margin * 2) - (cardPadding * 2), 16);
    self.riskTakeLabel.frame = CGRectMake(cardPadding, 66, width - (margin * 2) - (cardPadding * 2), 16);
    self.riskConfigureButton.frame = CGRectMake(cardPadding, 96, width - (margin * 2) - (cardPadding * 2), 36);
    y += 166;

    self.activityCard.frame = CGRectMake(margin, y, width - (margin * 2), 220);
    self.orderButton.frame = CGRectMake(cardPadding, 12, width - (margin * 2) - (cardPadding * 2), 32);
    self.ordersLabel.frame = CGRectMake(cardPadding, 54, width - (margin * 2) - (cardPadding * 2), 70);
    self.tradesLabel.frame = CGRectMake(cardPadding, 128, width - (margin * 2) - (cardPadding * 2), 70);
    y += 236;

    self.watchlistCard.frame = CGRectMake(margin, y, width - (margin * 2), 170);
    self.watchlistLabel.frame = CGRectMake(cardPadding, 14, width - (margin * 2) - (cardPadding * 2), 140);
    y += 186;

    self.tradingCard.frame = CGRectMake(margin, y, width - (margin * 2), 200);
    self.tradeButton.frame = CGRectMake(cardPadding, 12, width - (margin * 2) - (cardPadding * 2), 44);
    self.aiDecisionLabel.frame = CGRectMake(cardPadding, 64, width - (margin * 2) - (cardPadding * 2), 36);
    self.aiStrategyLabel.frame = CGRectMake(cardPadding, 102, width - (margin * 2) - (cardPadding * 2), 16);
    self.aiConfidenceLabel.frame = CGRectMake(cardPadding, 120, width - (margin * 2) - (cardPadding * 2), 16);
    self.aiConfidenceBar.frame = CGRectMake(cardPadding, 140, width - (margin * 2) - (cardPadding * 2), 6);
    self.statusLabel.frame = CGRectMake(cardPadding, 150, width - (margin * 2) - (cardPadding * 2), 36);
    y += 220;

    self.scrollView.contentSize = CGSizeMake(width, y + 20);

    [self layoutSideMenu];
}

@end
