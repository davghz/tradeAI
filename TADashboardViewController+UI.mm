/**
 * TADashboardViewController+UI.mm
 */

#import "TADashboardViewController+Private.h"
#import "TAAppDebugLog.h"
#import "TAGlassCardView.h"
#import <QuartzCore/QuartzCore.h>

@implementation TADashboardViewController (UI)

- (void)setupUI {
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    self.scrollView.alwaysBounceVertical = YES;
    self.scrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.scrollView];

    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[(id)[UIColor colorWithRed:0.05 green:0.06 blue:0.10 alpha:1.0].CGColor,
                                  (id)[UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0].CGColor];
    self.gradientLayer.startPoint = CGPointMake(0, 0);
    self.gradientLayer.endPoint = CGPointMake(1, 1);
    [self.view.layer insertSublayer:self.gradientLayer atIndex:0];

    self.titleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.titleLabel.text = @"TradeAI";
    self.titleLabel.textColor = [UIColor colorWithWhite:0.9 alpha:1.0];
    self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    [self.scrollView addSubview:self.titleLabel];

    self.authLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.authLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.authLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightSemibold];
    self.authLabel.text = @"⚠️ API: Not Configured";
    [self.scrollView addSubview:self.authLabel];

    self.modelLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.modelLabel.textColor = [UIColor colorWithWhite:0.6 alpha:1.0];
    self.modelLabel.font = [UIFont systemFontOfSize:11];
    self.modelLabel.text = @"AI Model: not set";
    [self.scrollView addSubview:self.modelLabel];

    self.priceCard = [self createCard];
    [self.scrollView addSubview:self.priceCard];

    self.symbolButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.symbolButton setTitle:@"BTC-USD ▼" forState:UIControlStateNormal];
    [self.symbolButton setTitleColor:[UIColor colorWithRed:0.2 green:0.9 blue:0.7 alpha:1.0] forState:UIControlStateNormal];
    self.symbolButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [self.symbolButton addTarget:self action:@selector(selectSymbol) forControlEvents:UIControlEventTouchUpInside];
    [self.priceCard addSubview:self.symbolButton];

    self.priceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.priceLabel.textColor = [UIColor whiteColor];
    self.priceLabel.font = [UIFont monospacedDigitSystemFontOfSize:38 weight:UIFontWeightBold];
    self.priceLabel.text = @"--";
    [self.priceCard addSubview:self.priceLabel];

    self.changeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.changeLabel.textColor = [UIColor lightGrayColor];
    self.changeLabel.font = [UIFont systemFontOfSize:13];
    self.changeLabel.text = @"24h: --";
    [self.priceCard addSubview:self.changeLabel];

    self.bidAskLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.bidAskLabel.textColor = [UIColor lightGrayColor];
    self.bidAskLabel.font = [UIFont systemFontOfSize:12];
    self.bidAskLabel.text = @"Bid/Ask: --";
    [self.priceCard addSubview:self.bidAskLabel];

    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statsLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.statsLabel.font = [UIFont systemFontOfSize:11];
    self.statsLabel.text = @"High/Low: -- • Vol: --";
    [self.priceCard addSubview:self.statsLabel];

    self.chartCard = [self createCard];
    [self.scrollView addSubview:self.chartCard];

    self.timeframeControl = [[UISegmentedControl alloc] initWithItems:@[@"1H", @"1D", @"1W", @"1M"]];
    self.timeframeControl.selectedSegmentIndex = 1;
    self.timeframeControl.selectedSegmentTintColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.7 alpha:1.0];
    self.timeframeControl.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.timeframeControl.layer.cornerRadius = 12;
    self.timeframeControl.layer.masksToBounds = YES;
    NSDictionary *normalAttrs = @{
        NSForegroundColorAttributeName: [UIColor colorWithWhite:0.85 alpha:1.0],
        NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]
    };
    NSDictionary *selectedAttrs = @{
        NSForegroundColorAttributeName: [UIColor blackColor],
        NSFontAttributeName: [UIFont systemFontOfSize:12 weight:UIFontWeightSemibold]
    };
    [self.timeframeControl setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
    [self.timeframeControl setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];
    [self.timeframeControl addTarget:self action:@selector(timeframeChanged) forControlEvents:UIControlEventValueChanged];
    [self.chartCard addSubview:self.timeframeControl];

    self.chartView = [[TAChartView alloc] initWithFrame:CGRectZero];
    self.chartView.backgroundColor = [UIColor clearColor];
    [self.chartCard addSubview:self.chartView];

    self.performanceCard = [self createCard];
    [self.scrollView addSubview:self.performanceCard];

    self.performanceAccentView = [[UIView alloc] initWithFrame:CGRectZero];
    self.performanceAccentView.backgroundColor = [UIColor colorWithRed:0.25 green:0.85 blue:0.95 alpha:1.0];
    self.performanceAccentView.layer.cornerRadius = 2;
    [self.performanceCard addSubview:self.performanceAccentView];

    UIImage *perfIcon = [UIImage systemImageNamed:@"chart.line.uptrend.xyaxis"];
    self.performanceIconView = [[UIImageView alloc] initWithImage:perfIcon];
    self.performanceIconView.tintColor = [UIColor colorWithRed:0.25 green:0.85 blue:0.95 alpha:1.0];
    self.performanceIconView.contentMode = UIViewContentModeScaleAspectFit;
    [self.performanceCard addSubview:self.performanceIconView];

    self.performanceTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.performanceTitleLabel.textColor = [UIColor whiteColor];
    self.performanceTitleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.performanceTitleLabel.text = @"Performance Snapshot";
    [self.performanceCard addSubview:self.performanceTitleLabel];

    self.performanceChangeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.performanceChangeLabel.textColor = [UIColor lightGrayColor];
    self.performanceChangeLabel.font = [UIFont systemFontOfSize:12];
    self.performanceChangeLabel.text = @"Change: --";
    [self.performanceCard addSubview:self.performanceChangeLabel];

    self.performanceRangeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.performanceRangeLabel.textColor = [UIColor lightGrayColor];
    self.performanceRangeLabel.font = [UIFont systemFontOfSize:12];
    self.performanceRangeLabel.text = @"Range: --";
    [self.performanceCard addSubview:self.performanceRangeLabel];

    self.performanceVolLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.performanceVolLabel.textColor = [UIColor lightGrayColor];
    self.performanceVolLabel.font = [UIFont systemFontOfSize:12];
    self.performanceVolLabel.text = @"Volatility: --";
    [self.performanceCard addSubview:self.performanceVolLabel];

    self.performanceMomentumLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.performanceMomentumLabel.textColor = [UIColor lightGrayColor];
    self.performanceMomentumLabel.font = [UIFont systemFontOfSize:12];
    self.performanceMomentumLabel.text = @"Momentum: --";
    [self.performanceCard addSubview:self.performanceMomentumLabel];

    self.performanceMomentumBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.performanceMomentumBar.progressTintColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.7 alpha:1.0];
    self.performanceMomentumBar.trackTintColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [self.performanceCard addSubview:self.performanceMomentumBar];

    self.portfolioCard = [self createCard];
    [self.scrollView addSubview:self.portfolioCard];

    self.balanceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.balanceLabel.textColor = [UIColor whiteColor];
    self.balanceLabel.font = [UIFont boldSystemFontOfSize:18];
    self.balanceLabel.text = @"Portfolio: --";
    [self.portfolioCard addSubview:self.balanceLabel];

    self.portfolioHoldingsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.portfolioHoldingsLabel.textColor = [UIColor lightGrayColor];
    self.portfolioHoldingsLabel.font = [UIFont systemFontOfSize:12];
    self.portfolioHoldingsLabel.numberOfLines = 0;
    self.portfolioHoldingsLabel.text = @"Holdings will appear here";
    [self.portfolioCard addSubview:self.portfolioHoldingsLabel];

    self.riskCard = [self createCard];
    [self.scrollView addSubview:self.riskCard];

    self.riskTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.riskTitleLabel.textColor = [UIColor whiteColor];
    self.riskTitleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.riskTitleLabel.text = @"Risk Controls";
    [self.riskCard addSubview:self.riskTitleLabel];

    self.riskEnabledSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.riskEnabledSwitch.onTintColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.3 alpha:1.0];
    [self.riskEnabledSwitch addTarget:self action:@selector(riskSwitchChanged) forControlEvents:UIControlEventValueChanged];
    [self.riskCard addSubview:self.riskEnabledSwitch];

    self.riskStopLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.riskStopLabel.textColor = [UIColor lightGrayColor];
    self.riskStopLabel.font = [UIFont systemFontOfSize:12];
    self.riskStopLabel.text = @"Stop Loss: --";
    [self.riskCard addSubview:self.riskStopLabel];

    self.riskTakeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.riskTakeLabel.textColor = [UIColor lightGrayColor];
    self.riskTakeLabel.font = [UIFont systemFontOfSize:12];
    self.riskTakeLabel.text = @"Take Profit: --";
    [self.riskCard addSubview:self.riskTakeLabel];

    self.riskConfigureButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.riskConfigureButton setTitle:@"Configure Risk Targets" forState:UIControlStateNormal];
    [self.riskConfigureButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.riskConfigureButton.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.riskConfigureButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    self.riskConfigureButton.layer.cornerRadius = 8;
    [self.riskConfigureButton addTarget:self action:@selector(configureRisk) forControlEvents:UIControlEventTouchUpInside];
    [self.riskCard addSubview:self.riskConfigureButton];

    self.activityCard = [self createCard];
    [self.scrollView addSubview:self.activityCard];

    self.orderButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.orderButton setTitle:@"Place Market Order" forState:UIControlStateNormal];
    [self.orderButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.orderButton.backgroundColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.orderButton.layer.cornerRadius = 8;
    self.orderButton.titleLabel.font = [UIFont boldSystemFontOfSize:14];
    [self.orderButton addTarget:self action:@selector(placeOrder) forControlEvents:UIControlEventTouchUpInside];
    [self.activityCard addSubview:self.orderButton];

    self.ordersLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.ordersLabel.textColor = [UIColor lightGrayColor];
    self.ordersLabel.font = [UIFont systemFontOfSize:12];
    self.ordersLabel.numberOfLines = 0;
    self.ordersLabel.text = @"Orders: --";
    [self.activityCard addSubview:self.ordersLabel];

    self.tradesLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.tradesLabel.textColor = [UIColor lightGrayColor];
    self.tradesLabel.font = [UIFont systemFontOfSize:12];
    self.tradesLabel.numberOfLines = 0;
    self.tradesLabel.text = @"Recent trades: --";
    [self.activityCard addSubview:self.tradesLabel];

    self.watchlistCard = [self createCard];
    [self.scrollView addSubview:self.watchlistCard];

    self.watchlistLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.watchlistLabel.textColor = [UIColor lightGrayColor];
    self.watchlistLabel.font = [UIFont systemFontOfSize:12];
    self.watchlistLabel.numberOfLines = 0;
    self.watchlistLabel.text = @"Watchlist loading...";
    [self.watchlistCard addSubview:self.watchlistLabel];

    self.tradingCard = [self createCard];
    [self.scrollView addSubview:self.tradingCard];

    self.tradeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.tradeButton setTitle:@"▶ START AI TRADING" forState:UIControlStateNormal];
    [self.tradeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.tradeButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    self.tradeButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.3 alpha:1.0];
    self.tradeButton.layer.cornerRadius = 10;
    [self.tradeButton addTarget:self action:@selector(toggleTrading) forControlEvents:UIControlEventTouchUpInside];
    [self.tradingCard addSubview:self.tradeButton];

    self.aiDecisionLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.aiDecisionLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    self.aiDecisionLabel.font = [UIFont systemFontOfSize:12];
    self.aiDecisionLabel.numberOfLines = 0;
    self.aiDecisionLabel.text = @"AI Signal: --";
    [self.tradingCard addSubview:self.aiDecisionLabel];

    self.aiStrategyLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.aiStrategyLabel.textColor = [UIColor colorWithWhite:0.75 alpha:1.0];
    self.aiStrategyLabel.font = [UIFont systemFontOfSize:11];
    self.aiStrategyLabel.text = @"Strategy: Balanced";
    [self.tradingCard addSubview:self.aiStrategyLabel];

    self.aiConfidenceLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.aiConfidenceLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.aiConfidenceLabel.font = [UIFont systemFontOfSize:11];
    self.aiConfidenceLabel.text = @"Confidence: --";
    [self.tradingCard addSubview:self.aiConfidenceLabel];

    self.aiConfidenceBar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    self.aiConfidenceBar.progressTintColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.7 alpha:1.0];
    self.aiConfidenceBar.trackTintColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    [self.tradingCard addSubview:self.aiConfidenceBar];

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statusLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.statusLabel.font = [UIFont systemFontOfSize:12];
    self.statusLabel.numberOfLines = 0;
    self.statusLabel.text = @"Configure API keys and model in Settings";
    [self.tradingCard addSubview:self.statusLabel];

    [self updateRiskLabels];
    [self updateStrategyLabel];
    [self setupSideMenu];
    TASetDebugStage(@"dashboard_setupUI_finish");
}

- (UIView *)createCard {
    return [[TAGlassCardView alloc] initWithFrame:CGRectZero];
}

@end
