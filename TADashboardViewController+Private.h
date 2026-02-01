/**
 * TADashboardViewController+Private.h
 */

#import "TADashboardViewController.h"
#import "TAChartView.h"

NS_ASSUME_NONNULL_BEGIN

@interface TADashboardViewController () <UITextFieldDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;

@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UILabel *authLabel;
@property (nonatomic, strong) UILabel *modelLabel;
@property (nonatomic, strong) UILabel *statusLabel;

@property (nonatomic, strong) UIButton *symbolButton;
@property (nonatomic, strong) UIButton *tradeButton;
@property (nonatomic, strong) UIButton *orderButton;

@property (nonatomic, strong) UIView *priceCard;
@property (nonatomic, strong) UILabel *priceLabel;
@property (nonatomic, strong) UILabel *changeLabel;
@property (nonatomic, strong) UILabel *bidAskLabel;
@property (nonatomic, strong) UILabel *statsLabel;

@property (nonatomic, strong) UIView *chartCard;
@property (nonatomic, strong) TAChartView *chartView;
@property (nonatomic, strong) UISegmentedControl *timeframeControl;

@property (nonatomic, strong) UIView *performanceCard;
@property (nonatomic, strong) UIView *performanceAccentView;
@property (nonatomic, strong) UIImageView *performanceIconView;
@property (nonatomic, strong) UILabel *performanceTitleLabel;
@property (nonatomic, strong) UILabel *performanceChangeLabel;
@property (nonatomic, strong) UILabel *performanceRangeLabel;
@property (nonatomic, strong) UILabel *performanceVolLabel;
@property (nonatomic, strong) UILabel *performanceMomentumLabel;
@property (nonatomic, strong) UIProgressView *performanceMomentumBar;

@property (nonatomic, strong) UIView *portfolioCard;
@property (nonatomic, strong) UILabel *balanceLabel;
@property (nonatomic, strong) UILabel *portfolioHoldingsLabel;

@property (nonatomic, strong) UIView *riskCard;
@property (nonatomic, strong) UILabel *riskTitleLabel;
@property (nonatomic, strong) UILabel *riskStopLabel;
@property (nonatomic, strong) UILabel *riskTakeLabel;
@property (nonatomic, strong) UISwitch *riskEnabledSwitch;
@property (nonatomic, strong) UIButton *riskConfigureButton;

@property (nonatomic, strong) UIView *activityCard;
@property (nonatomic, strong) UILabel *ordersLabel;
@property (nonatomic, strong) UILabel *tradesLabel;

@property (nonatomic, strong) UIView *watchlistCard;
@property (nonatomic, strong) UILabel *watchlistLabel;

@property (nonatomic, strong) UIView *tradingCard;
@property (nonatomic, strong) UILabel *aiDecisionLabel;
@property (nonatomic, strong) UILabel *aiStrategyLabel;
@property (nonatomic, strong) UILabel *aiConfidenceLabel;
@property (nonatomic, strong) UIProgressView *aiConfidenceBar;

@property (nonatomic, copy) NSString *selectedSymbol;
@property (nonatomic, assign) BOOL isTrading;
@property (nonatomic, strong) NSTimer *refreshTimer;
@property (nonatomic, strong) NSArray *symbols;
@property (nonatomic, strong) NSArray *products;
@property (nonatomic, copy) NSString *lastOrderId;
@property (nonatomic, strong) NSDate *lastProductsFetch;
@property (nonatomic, strong) NSDate *lastCandlesFetch;
@property (nonatomic, strong) NSDate *lastTradesFetch;
@property (nonatomic, strong) NSDate *lastOrdersFetch;
@property (nonatomic, copy) NSString *latestPrice;
@property (nonatomic, strong) NSDate *lastAIRequestAt;
@property (nonatomic, strong) NSDate *lastAITradeAt;
@property (nonatomic, copy) NSString *lastAISignal;
@property (nonatomic, copy) NSString *lastJournalEntryId;
@property (nonatomic, strong) UIView *sideMenuOverlay;
@property (nonatomic, strong) UIView *sideMenuContainer;
@property (nonatomic, strong) UIStackView *sideMenuStack;
@property (nonatomic, strong) UILabel *sideMenuHeaderLabel;
@property (nonatomic, assign) BOOL sideMenuVisible;

- (void)setupUI;
- (UIView *)createCard;
- (void)setupSideMenu;
- (void)layoutSideMenu;
- (void)toggleSideMenu;
- (void)showSideMenu;
- (void)hideSideMenu;
- (void)loadAPISettings;
- (void)refreshData;
- (void)updateRiskLabels;
- (void)updateStrategyLabel;
- (NSString *)currentStrategyName;
- (NSString *)selectedGranularity;
- (NSArray<NSNumber *> *)closeSeriesFromCandles:(NSArray *)candles;
- (void)updatePerformanceWithCandles:(NSArray *)candles;
- (void)configureRisk;
- (void)riskSwitchChanged;
- (void)timeframeChanged;
- (void)toggleTrading;
- (void)startTrading;
- (void)stopTrading;
- (void)placeOrder;
- (void)submitOrderWithSide:(NSString *)side size:(NSString *)sizeText;
- (void)showToast:(NSString *)message;
- (void)openSettings;
- (void)selectSymbol;
- (NSString *)actionFromDecision:(NSString *)decision;
- (void)maybeAutoTradeWithAction:(NSString *)action;
- (void)maybeRequestAIRecommendationWithAccounts:(NSArray<NSDictionary *> *)accounts;

@end

NS_ASSUME_NONNULL_END
