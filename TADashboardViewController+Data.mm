/**
 * TADashboardViewController+Data.mm
 */

#import "TADashboardViewController+Private.h"
#import "TACoinbaseAPI.h"
#import "TAOpenRouterClient.h"
#import <float.h>
#import <math.h>

@implementation TADashboardViewController (Data)

- (void)loadAPISettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *apiKey = [defaults stringForKey:@"coinbase_api_key"];
    NSString *privateKey = [defaults stringForKey:@"coinbase_private_key"];

    [defaults setObject:[[NSDate date] description] forKey:@"debug_last_loaded"];
    [defaults synchronize];

    NSString *model = [defaults stringForKey:@"openrouter_model"];
    if (model.length > 0) {
        self.modelLabel.text = [NSString stringWithFormat:@"AI Model: %@", model];
    } else {
        self.modelLabel.text = @"AI Model: not set";
    }
    [[TAOpenRouterClient sharedInstance] setModel:(model.length > 0 ? model : @"")];
    NSString *openRouterKey = [defaults stringForKey:@"openrouter_api_key"];
    [[TAOpenRouterClient sharedInstance] setAPIKey:(openRouterKey.length > 0 ? openRouterKey : @"")];
    [self updateStrategyLabel];

    if (apiKey.length > 0 && privateKey.length > 0) {
        TACoinbaseAPI *api = [TACoinbaseAPI sharedInstance];
        [api setAPIKey:apiKey apiPrivateKey:privateKey];

        self.authLabel.text = @"🔐 API: Configured";
        self.authLabel.textColor = [UIColor colorWithRed:0.3 green:0.9 blue:0.6 alpha:1.0];
        self.statusLabel.text = @"Connecting to Coinbase Advanced Trade API v3...";
        NSLog(@"[Dashboard] API credentials loaded");
    } else {
        NSLog(@"[Dashboard] API credentials not found");
    }
}

- (void)refreshData {
    TACoinbaseAPI *api = [TACoinbaseAPI sharedInstance];
    BOOL configured = api.isConfigured;
    if (configured) {
        self.statusLabel.text = @"Syncing market data...";
    } else {
        self.statusLabel.text = @"Market data only — connect API + model for trading";
        self.balanceLabel.text = @"Portfolio: connect API";
        self.portfolioHoldingsLabel.text = @"Holdings will appear here";
        self.ordersLabel.text = @"Recent Orders\nConnect API to view orders";
    }

    // Best bid/ask
    [api getBestBidAsk:@[self.selectedSymbol] completion:^(NSDictionary *data, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                self.statusLabel.text = [NSString stringWithFormat:@"Market error: %@", error.localizedDescription];
                return;
            }
            NSDictionary *book = data[@"pricebook"];
            if (!book) {
                NSArray *pricebooks = data[@"pricebooks"];
                if ([pricebooks isKindOfClass:[NSArray class]] && pricebooks.count > 0) {
                    book = pricebooks[0];
                }
            }
            id bidsObj = book[@"bids"];
            id asksObj = book[@"asks"];
            NSDictionary *bid = [bidsObj isKindOfClass:[NSArray class]] ? [bidsObj firstObject] : bidsObj;
            NSDictionary *ask = [asksObj isKindOfClass:[NSArray class]] ? [asksObj firstObject] : asksObj;
            NSString *bidPrice = bid[@"price"] ?: data[@"best_bid"] ?: @"--";
            NSString *askPrice = ask[@"price"] ?: data[@"best_ask"] ?: @"--";
            if (bidPrice || askPrice) {
                self.bidAskLabel.text = [NSString stringWithFormat:@"Bid %@  •  Ask %@", bidPrice ?: @"--", askPrice ?: @"--"];
            }
        });
    }];

    __block NSString *currentPrice = nil;
    // Product details
    [api getProduct:self.selectedSymbol completion:^(NSDictionary *product, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                self.statusLabel.text = [NSString stringWithFormat:@"Market error: %@", error.localizedDescription];
                return;
            }
            NSDictionary *productInfo = product[@"product"] ?: product;
            NSString *price = productInfo[@"price"] ?: productInfo[@"price_usd"] ?: @"--";
            currentPrice = price;
            self.latestPrice = price;
            NSString *change = productInfo[@"price_percentage_change_24h"] ?: @"--";
            NSString *changeText = change;
            if (change.length > 0 && ![change containsString:@"%"] && ![change isEqualToString:@"--"]) {
                changeText = [NSString stringWithFormat:@"%@%%", change];
            }
            NSString *high = productInfo[@"high_24h"] ?: productInfo[@"high"] ?: @"--";
            NSString *low = productInfo[@"low_24h"] ?: productInfo[@"low"] ?: @"--";
            NSString *volume = productInfo[@"volume_24h"] ?: productInfo[@"volume"] ?: @"--";

            if (![price isEqualToString:@"--"]) {
                self.priceLabel.text = [NSString stringWithFormat:@"$%@", price];
            }
            self.changeLabel.text = [NSString stringWithFormat:@"24h: %@", changeText ?: @"--"];
            self.statsLabel.text = [NSString stringWithFormat:@"High %@  •  Low %@  •  Vol %@", high, low, volume];
        });
    }];

    // Candles (chart)
    if (!self.lastCandlesFetch || [[NSDate date] timeIntervalSinceDate:self.lastCandlesFetch] > 30) {
        self.lastCandlesFetch = [NSDate date];
        [api getProductCandles:self.selectedSymbol granularity:[self selectedGranularity] completion:^(NSArray *candles, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    self.statusLabel.text = [NSString stringWithFormat:@"Chart error: %@", error.localizedDescription];
                    return;
                }
                [self.chartView updateWithCandles:candles];
                [self updatePerformanceWithCandles:candles];
            });
        }];
    }

    // Accounts/portfolio (authenticated)
    if (configured) {
        [api getAccounts:^(NSArray<TAAccount *> *accounts, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                NSMutableArray<NSDictionary *> *accountPayload = [NSMutableArray array];
                if (!error && accounts.count > 0) {
                    NSDecimalNumber *totalUSD = [NSDecimalNumber zero];
                    NSMutableArray<NSString *> *lines = [NSMutableArray array];
                    for (TAAccount *acc in accounts) {
                        if ([acc.currency isEqualToString:@"USD"]) {
                            totalUSD = [totalUSD decimalNumberByAdding:acc.available];
                        }
                        if ([acc.total compare:[NSDecimalNumber zero]] == NSOrderedDescending) {
                            NSString *line = [NSString stringWithFormat:@"%@  %@", acc.currency, acc.total.stringValue];
                            [lines addObject:line];
                            [accountPayload addObject:@{ @"currency": acc.currency ?: @"", @"total": acc.total.stringValue ?: @"0" }];
                        }
                    }
                    self.balanceLabel.text = [NSString stringWithFormat:@"Portfolio (USD): $%.2f", totalUSD.doubleValue];
                    NSString *holdingsText = lines.count > 0 ? [lines componentsJoinedByString:@"\n"] : @"No balances yet";
                    self.portfolioHoldingsLabel.text = [NSString stringWithFormat:@"Holdings\n%@", holdingsText];
                } else {
                    if (error) {
                        self.balanceLabel.text = @"Portfolio: unavailable";
                        self.portfolioHoldingsLabel.text = [NSString stringWithFormat:@"Holdings\n%@", error.localizedDescription];
                    } else {
                        self.balanceLabel.text = @"Portfolio (USD): $0.00";
                        self.portfolioHoldingsLabel.text = @"Holdings\nNo balances yet";
                    }
                }

                [self maybeRequestAIRecommendationWithAccounts:accountPayload];
            });
        }];
    }

    // Orders (authenticated)
    if (configured && (!self.lastOrdersFetch || [[NSDate date] timeIntervalSinceDate:self.lastOrdersFetch] > 20)) {
        self.lastOrdersFetch = [NSDate date];
        [api listOrders:^(NSArray<TAOrder *> *orders, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    self.ordersLabel.text = [NSString stringWithFormat:@"Orders: %@", error.localizedDescription];
                    return;
                }
                NSMutableArray<NSString *> *lines = [NSMutableArray array];
                NSInteger count = MIN(3, orders.count);
                for (NSInteger i = 0; i < count; i++) {
                    TAOrder *order = orders[i];
                    NSString *line = [NSString stringWithFormat:@"%@ %@ %@", order.side ?: @"--", order.productId ?: @"--", order.status ?: @"--"];
                    [lines addObject:line];
                }
                self.lastOrderId = orders.firstObject.orderId;
                NSString *ordersText = lines.count > 0 ? [lines componentsJoinedByString:@"\n"] : @"No orders found";
                self.ordersLabel.text = [NSString stringWithFormat:@"Recent Orders\n%@", ordersText];

                if (self.lastOrderId.length > 0) {
                    [api getOrder:self.lastOrderId completion:^(TAOrder *order, NSError *orderError) {
                        if (!orderError && order.orderId.length > 0) {
                            dispatch_async(dispatch_get_main_queue(), ^{
                                self.ordersLabel.text = [NSString stringWithFormat:@"Recent Orders\n%@\nLast: %@ (%@)", ordersText, order.orderId, order.status ?: @"--"];
                            });
                        }
                    }];
                }
            });
        }];
    }

    // Trades
    if (!self.lastTradesFetch || [[NSDate date] timeIntervalSinceDate:self.lastTradesFetch] > 15) {
        self.lastTradesFetch = [NSDate date];
        [api getMarketTrades:self.selectedSymbol completion:^(NSArray *trades, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    self.tradesLabel.text = [NSString stringWithFormat:@"Recent Trades\n%@", error.localizedDescription];
                    return;
                }
                NSMutableArray<NSString *> *lines = [NSMutableArray array];
                NSInteger count = MIN(3, trades.count);
                for (NSInteger i = 0; i < count; i++) {
                    NSDictionary *trade = trades[i];
                    NSString *price = trade[@"price"] ?: @"--";
                    NSString *size = trade[@"size"] ?: @"--";
                    NSString *side = trade[@"side"] ?: trade[@"trade_side"] ?: @"--";
                    NSString *line = [NSString stringWithFormat:@"%@ %@ @ %@", [side uppercaseString], size, price];
                    [lines addObject:line];
                }
                NSString *tradeText = lines.count > 0 ? [lines componentsJoinedByString:@"\n"] : @"No trades";
                self.tradesLabel.text = [NSString stringWithFormat:@"Recent Trades\n%@", tradeText];
            });
        }];
    }

    // Products / watchlist (less frequent)
    if (!self.lastProductsFetch || [[NSDate date] timeIntervalSinceDate:self.lastProductsFetch] > 60) {
        self.lastProductsFetch = [NSDate date];
        [api getProducts:^(NSArray *products, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    self.watchlistLabel.text = [NSString stringWithFormat:@"Watchlist\n%@", error.localizedDescription];
                    return;
                }
                self.products = products;
                NSMutableArray<NSString *> *lines = [NSMutableArray array];
                NSInteger count = MIN(5, products.count);
                for (NSInteger i = 0; i < count; i++) {
                    NSDictionary *product = products[i];
                    NSString *symbol = product[@"product_id"] ?: product[@"id"] ?: @"--";
                    NSString *price = product[@"price"] ?: @"--";
                    NSString *line = [NSString stringWithFormat:@"%@  %@", symbol, price];
                    [lines addObject:line];
                }
                NSString *watchText = lines.count > 0 ? [lines componentsJoinedByString:@"\n"] : @"No products";
                self.watchlistLabel.text = [NSString stringWithFormat:@"Watchlist\n%@", watchText];
            });
        }];
    }
}

- (NSString *)selectedGranularity {
    switch (self.timeframeControl.selectedSegmentIndex) {
        case 0: return @"ONE_MINUTE"; // ~1H
        case 1: return @"FIFTEEN_MINUTE"; // ~1D
        case 2: return @"ONE_HOUR"; // ~1W
        case 3: return @"ONE_DAY"; // ~1M
        default: return @"ONE_HOUR";
    }
}

- (NSArray<NSNumber *> *)closeSeriesFromCandles:(NSArray *)candles {
    NSMutableArray<NSNumber *> *closes = [NSMutableArray array];
    for (id candle in candles) {
        double value = NAN;
        if ([candle isKindOfClass:[NSDictionary class]]) {
            NSDictionary *dict = (NSDictionary *)candle;
            id closeVal = dict[@"close"] ?: dict[@"close_price"] ?: dict[@"price"];
            if ([closeVal isKindOfClass:[NSNumber class]]) {
                value = [(NSNumber *)closeVal doubleValue];
            } else if ([closeVal isKindOfClass:[NSString class]]) {
                value = [(NSString *)closeVal doubleValue];
            } else if ([closeVal isKindOfClass:[NSDictionary class]]) {
                id inner = ((NSDictionary *)closeVal)[@"value"] ?: ((NSDictionary *)closeVal)[@"amount"];
                if ([inner isKindOfClass:[NSNumber class]]) {
                    value = [(NSNumber *)inner doubleValue];
                } else if ([inner isKindOfClass:[NSString class]]) {
                    value = [(NSString *)inner doubleValue];
                }
            }
        } else if ([candle isKindOfClass:[NSArray class]]) {
            NSArray *arr = (NSArray *)candle;
            if (arr.count >= 5) {
                id closeVal = [arr lastObject];
                if ([closeVal isKindOfClass:[NSNumber class]]) {
                    value = [(NSNumber *)closeVal doubleValue];
                } else if ([closeVal isKindOfClass:[NSString class]]) {
                    value = [(NSString *)closeVal doubleValue];
                }
            }
        } else if ([candle isKindOfClass:[NSNumber class]]) {
            value = [(NSNumber *)candle doubleValue];
        } else if ([candle isKindOfClass:[NSString class]]) {
            value = [(NSString *)candle doubleValue];
        }

        if (!isnan(value)) {
            [closes addObject:@(value)];
        }
    }
    return closes;
}

- (void)updatePerformanceWithCandles:(NSArray *)candles {
    NSArray<NSNumber *> *closes = [self closeSeriesFromCandles:candles];
    if (closes.count < 2) {
        self.performanceChangeLabel.text = @"Change: --";
        self.performanceRangeLabel.text = @"Range: --";
        self.performanceVolLabel.text = @"Volatility: --";
        self.performanceMomentumLabel.text = @"Momentum: --";
        self.performanceMomentumBar.progress = 0.0;
        return;
    }

    double first = closes.firstObject.doubleValue;
    double last = closes.lastObject.doubleValue;
    double minVal = DBL_MAX;
    double maxVal = DBL_MIN;
    for (NSNumber *num in closes) {
        double v = num.doubleValue;
        minVal = MIN(minVal, v);
        maxVal = MAX(maxVal, v);
    }

    double changePct = (first != 0.0) ? ((last - first) / first) * 100.0 : 0.0;
    double rangePct = (first != 0.0) ? ((maxVal - minVal) / first) * 100.0 : 0.0;

    double mean = 0.0;
    NSInteger returnsCount = closes.count - 1;
    NSMutableArray<NSNumber *> *returns = [NSMutableArray arrayWithCapacity:returnsCount];
    for (NSInteger i = 1; i < closes.count; i++) {
        double prev = closes[i - 1].doubleValue;
        double cur = closes[i].doubleValue;
        double r = (prev != 0.0) ? ((cur - prev) / prev) : 0.0;
        [returns addObject:@(r)];
        mean += r;
    }
    mean /= MAX(returns.count, 1);
    double variance = 0.0;
    for (NSNumber *num in returns) {
        double diff = num.doubleValue - mean;
        variance += diff * diff;
    }
    double volatility = sqrt(variance / MAX(returns.count, 1)) * 100.0;

    double sma = 0.0;
    NSInteger window = MIN(5, closes.count);
    for (NSInteger i = closes.count - window; i < closes.count; i++) {
        sma += closes[i].doubleValue;
    }
    sma /= MAX(window, 1);
    double momentum = (sma != 0.0) ? ((last - sma) / sma) : 0.0;

    self.performanceChangeLabel.text = [NSString stringWithFormat:@"Change: %.2f%%", changePct];
    self.performanceChangeLabel.textColor = (changePct >= 0.0) ? [UIColor colorWithRed:0.2 green:0.9 blue:0.7 alpha:1.0] : [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0];
    self.performanceRangeLabel.text = [NSString stringWithFormat:@"Range: %.2f%%", rangePct];
    self.performanceVolLabel.text = [NSString stringWithFormat:@"Volatility: %.2f%%", volatility];
    self.performanceMomentumLabel.text = [NSString stringWithFormat:@"Momentum: %.2f%%", momentum * 100.0];

    double normalized = (momentum + 0.05) / 0.10;
    normalized = MAX(0.0, MIN(1.0, normalized));
    self.performanceMomentumBar.progress = (float)normalized;
}

@end
