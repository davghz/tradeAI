/**
 * TAPortfolioViewController.mm
 */

#import "TAPortfolioViewController.h"
#import "TACoinbaseAPI.h"
#import "TAPortfolio.h"
#import "TAPortfolioDonutView.h"
#import "TAGlassCardView.h"
#import <QuartzCore/QuartzCore.h>

@interface TAPortfolioViewController ()
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) CAGradientLayer *gradientLayer;

@property (nonatomic, strong) UIView *summaryCard;
@property (nonatomic, strong) UILabel *totalValueLabel;
@property (nonatomic, strong) UILabel *pnlLabel;

@property (nonatomic, strong) UIView *donutCard;
@property (nonatomic, strong) TAPortfolioDonutView *donutView;
@property (nonatomic, strong) UILabel *donutLegendLabel;

@property (nonatomic, strong) UIView *holdingsCard;
@property (nonatomic, strong) UILabel *holdingsLabel;

@property (nonatomic, strong) NSArray<TAHolding *> *holdings;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *priceMap;
@end

@implementation TAPortfolioViewController

static BOOL TAIsFiatSymbol(NSString *symbol) {
    if (symbol.length == 0) {
        return NO;
    }
    NSString *upper = [symbol uppercaseString];
    return [upper isEqualToString:@"USD"] || [upper isEqualToString:@"USDC"] || [upper isEqualToString:@"USDT"];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Portfolio";
    self.view.backgroundColor = [UIColor blackColor];

    [self setupUI];
    [self refreshPortfolio];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshPortfolio];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    self.gradientLayer.frame = self.view.bounds;

    CGFloat width = self.view.bounds.size.width;
    CGFloat margin = 20;
    CGFloat y = 16;

    self.summaryCard.frame = CGRectMake(margin, y, width - margin * 2, 110);
    self.totalValueLabel.frame = CGRectMake(16, 18, self.summaryCard.bounds.size.width - 32, 26);
    self.pnlLabel.frame = CGRectMake(16, 54, self.summaryCard.bounds.size.width - 32, 20);
    y += 126;

    self.donutCard.frame = CGRectMake(margin, y, width - margin * 2, 240);
    self.donutView.frame = CGRectMake(20, 20, self.donutCard.bounds.size.width - 40, 160);
    self.donutLegendLabel.frame = CGRectMake(20, 184, self.donutCard.bounds.size.width - 40, 44);
    y += 256;

    self.holdingsCard.frame = CGRectMake(margin, y, width - margin * 2, 220);
    self.holdingsLabel.frame = CGRectMake(16, 16, self.holdingsCard.bounds.size.width - 32, 188);
    y += 236;

    self.scrollView.contentSize = CGSizeMake(width, y + 20);
}

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

    self.summaryCard = [self createCard];
    [self.scrollView addSubview:self.summaryCard];

    self.totalValueLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.totalValueLabel.textColor = [UIColor whiteColor];
    self.totalValueLabel.font = [UIFont boldSystemFontOfSize:22];
    self.totalValueLabel.text = @"Total Value: --";
    [self.summaryCard addSubview:self.totalValueLabel];

    self.pnlLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.pnlLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.pnlLabel.font = [UIFont systemFontOfSize:13];
    self.pnlLabel.text = @"Unrealized PnL: --";
    [self.summaryCard addSubview:self.pnlLabel];

    self.donutCard = [self createCard];
    [self.scrollView addSubview:self.donutCard];

    self.donutView = [[TAPortfolioDonutView alloc] initWithFrame:CGRectZero];
    [self.donutCard addSubview:self.donutView];

    self.donutLegendLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.donutLegendLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
    self.donutLegendLabel.font = [UIFont systemFontOfSize:11];
    self.donutLegendLabel.numberOfLines = 0;
    self.donutLegendLabel.text = @"Holdings breakdown will appear here";
    [self.donutCard addSubview:self.donutLegendLabel];

    self.holdingsCard = [self createCard];
    [self.scrollView addSubview:self.holdingsCard];

    self.holdingsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.holdingsLabel.textColor = [UIColor lightGrayColor];
    self.holdingsLabel.font = [UIFont systemFontOfSize:12];
    self.holdingsLabel.numberOfLines = 0;
    self.holdingsLabel.text = @"Holdings will appear here";
    [self.holdingsCard addSubview:self.holdingsLabel];
}

- (UIView *)createCard {
    return [[TAGlassCardView alloc] initWithFrame:CGRectZero];
}

- (void)refreshPortfolio {
    TACoinbaseAPI *api = [TACoinbaseAPI sharedInstance];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *apiKey = [defaults stringForKey:@"coinbase_api_key"];
    NSString *privateKey = [defaults stringForKey:@"coinbase_private_key"];
    if (apiKey.length > 0 && privateKey.length > 0) {
        [api setAPIKey:apiKey apiPrivateKey:privateKey];
    }
    NSString *edApiKey = [defaults stringForKey:@"coinbase_ed25519_api_key"];
    NSString *edPrivateKey = [defaults stringForKey:@"coinbase_ed25519_private_key"];
    if (edApiKey.length > 0 && edPrivateKey.length > 0) {
        [api setEd25519APIKey:edApiKey ed25519PrivateKey:edPrivateKey];
    }
    if (!api.isConfigured) {
        self.totalValueLabel.text = @"Total Value: connect API";
        self.pnlLabel.text = @"Unrealized PnL: --";
        self.holdingsLabel.text = @"Connect API credentials in Settings";
        [self.donutView updateWithHoldings:@[] totalValue:[NSDecimalNumber zero]];
        self.donutLegendLabel.text = @"No portfolio data";
        return;
    }

    [api getAccounts:^(NSArray<TAAccount *> *accounts, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                self.totalValueLabel.text = @"Total Value: unavailable";
                self.holdingsLabel.text = error.localizedDescription ?: @"Failed to load holdings";
                [self.donutView updateWithHoldings:@[] totalValue:[NSDecimalNumber zero]];
                self.donutLegendLabel.text = @"No portfolio data";
                return;
            }

            NSMutableArray<TAHolding *> *holdings = [NSMutableArray array];
            for (TAAccount *acc in accounts) {
                NSString *accountCurrency = acc.currency ?: @"";
                NSString *totalCurrency = acc.totalCurrency.length > 0 ? acc.totalCurrency : accountCurrency;
                BOOL totalIsFiat = TAIsFiatSymbol(totalCurrency) && accountCurrency.length > 0 && ![totalCurrency isEqualToString:accountCurrency];

                NSDecimalNumber *baseAmount = acc.total;
                if (!baseAmount || [baseAmount compare:[NSDecimalNumber zero]] != NSOrderedDescending) {
                    baseAmount = acc.available;
                }
                if (totalIsFiat) {
                    NSDecimalNumber *available = acc.available;
                    if (available && [available compare:[NSDecimalNumber zero]] == NSOrderedDescending) {
                        baseAmount = available;
                    }
                }
                if (!baseAmount || [baseAmount compare:[NSDecimalNumber zero]] != NSOrderedDescending) {
                    continue;
                }
                NSDecimalNumber *usdValue = nil;
                if (totalIsFiat) {
                    usdValue = acc.total;
                }
                TAHolding *holding = [[TAHolding alloc] init];
                holding.symbol = accountCurrency;
                holding.quantity = baseAmount;
                holding.avgPrice = [NSDecimalNumber zero];
                holding.currentPrice = [NSDecimalNumber one];
                if (usdValue && [usdValue compare:[NSDecimalNumber zero]] == NSOrderedDescending) {
                    if ([baseAmount compare:[NSDecimalNumber zero]] == NSOrderedDescending) {
                        holding.currentPrice = [usdValue decimalNumberByDividingBy:baseAmount];
                    }
                }
                [holdings addObject:holding];
            }

            [api getProducts:^(NSArray *products, NSError *productsError) {
                NSMutableDictionary<NSString *, NSString *> *map = [NSMutableDictionary dictionary];
                if (!productsError && [products isKindOfClass:[NSArray class]]) {
                    for (id entry in products) {
                        if (![entry isKindOfClass:[NSDictionary class]]) {
                            continue;
                        }
                        NSDictionary *product = (NSDictionary *)entry;
                        NSString *productId = product[@"product_id"] ?: product[@"id"];
                        NSString *price = product[@"price"] ?: product[@"price_usd"];
                        if (productId.length > 0 && price.length > 0) {
                            map[productId] = price;
                        }
                    }
                }
                self.priceMap = map;

                dispatch_group_t group = dispatch_group_create();
                for (TAHolding *holding in holdings) {
                    NSString *symbol = holding.symbol ?: @"";
                    if (symbol.length == 0) {
                        continue;
                    }
                    if (TAIsFiatSymbol(symbol)) {
                        holding.currentPrice = [NSDecimalNumber one];
                        continue;
                    }

                    NSString *usdPrice = map[[NSString stringWithFormat:@"%@-USD", symbol]];
                    NSString *usdcPrice = map[[NSString stringWithFormat:@"%@-USDC", symbol]];
                    NSString *usdtPrice = map[[NSString stringWithFormat:@"%@-USDT", symbol]];
                    NSString *priceStr = usdPrice ?: usdcPrice ?: usdtPrice;
                    if (priceStr.length > 0) {
                        holding.currentPrice = [NSDecimalNumber decimalNumberWithString:priceStr];
                        continue;
                    }

                    dispatch_group_enter(group);
                    [self fetchPriceForSymbol:symbol completion:^(NSDecimalNumber *price) {
                        holding.currentPrice = price ?: [NSDecimalNumber zero];
                        dispatch_group_leave(group);
                    }];
                }

                dispatch_group_notify(group, dispatch_get_main_queue(), ^{
                    NSNumberFormatter *usdFormatter = [[NSNumberFormatter alloc] init];
                    usdFormatter.numberStyle = NSNumberFormatterCurrencyStyle;
                    usdFormatter.currencyCode = @"USD";
                    usdFormatter.maximumFractionDigits = 2;

                    NSDecimalNumber *total = [NSDecimalNumber zero];
                    NSInteger missingPrices = 0;
                    NSMutableArray<NSString *> *lines = [NSMutableArray array];
                    for (TAHolding *holding in holdings) {
                        BOOL hasPrice = holding.currentPrice && [holding.currentPrice compare:[NSDecimalNumber zero]] == NSOrderedDescending;
                        NSDecimalNumber *value = hasPrice ? [holding value] : [NSDecimalNumber zero];
                        if (hasPrice) {
                            total = [total decimalNumberByAdding:value];
                        } else {
                            missingPrices += 1;
                        }

                        NSString *valueText = hasPrice ? [usdFormatter stringFromNumber:value] : @"N/A";
                        NSString *qtyText = holding.quantity.stringValue ?: @"--";
                        NSString *line = [NSString stringWithFormat:@"%@  %@  %@", holding.symbol, qtyText, valueText];
                        [lines addObject:line];
                    }
                    self.holdings = holdings;
                    NSString *totalText = [usdFormatter stringFromNumber:total] ?: [NSString stringWithFormat:@"$%.2f", total.doubleValue];
                    if (missingPrices > 0) {
                        self.totalValueLabel.text = [NSString stringWithFormat:@"Total Value: %@*", totalText];
                        self.pnlLabel.text = [NSString stringWithFormat:@"Unpriced assets: %ld", (long)missingPrices];
                    } else {
                        self.totalValueLabel.text = [NSString stringWithFormat:@"Total Value: %@", totalText];
                        self.pnlLabel.text = @"Unrealized PnL: --";
                    }
                    self.holdingsLabel.text = lines.count > 0 ? [lines componentsJoinedByString:@"\n"] : @"No balances yet";
                    [self.donutView updateWithHoldings:holdings totalValue:total];
                    self.donutLegendLabel.text = lines.count > 0 ? [lines componentsJoinedByString:@"  •  "] : @"No holdings";
                });
            }];
        });
    }];
}

- (void)fetchPriceForSymbol:(NSString *)symbol completion:(void (^)(NSDecimalNumber *price))completion {
    [self fetchPriceForSymbol:symbol quoteIndex:0 completion:completion];
}

- (void)fetchPriceForSymbol:(NSString *)symbol quoteIndex:(NSInteger)index completion:(void (^)(NSDecimalNumber *price))completion {
    NSArray<NSString *> *quotes = @[ @"USD", @"USDC", @"USDT" ];
    if (index >= quotes.count) {
        completion([NSDecimalNumber zero]);
        return;
    }
    NSString *quote = quotes[index];
    NSString *pair = [NSString stringWithFormat:@"%@-%@", symbol, quote];
    TACoinbaseAPI *api = [TACoinbaseAPI sharedInstance];
    [api getProduct:pair completion:^(NSDictionary *product, NSError *error) {
        if (!error) {
            NSDictionary *productInfo = product[@"product"] ?: product;
            NSString *priceStr = productInfo[@"price"] ?: productInfo[@"price_usd"];
            if (priceStr.length > 0) {
                completion([NSDecimalNumber decimalNumberWithString:priceStr]);
                return;
            }
        }
        [self fetchPriceForSymbol:symbol quoteIndex:index + 1 completion:completion];
    }];
}

@end
