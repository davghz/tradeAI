/**
 * TADashboardViewController+Trading.mm
 */

#import "TADashboardViewController+Private.h"
#import "TACoinbaseAPI.h"
#import "TASettingsViewController.h"
#import "TAOpenRouterClient.h"
#import "TATradeJournal.h"
#import "TAJournalStorage.h"

@implementation TADashboardViewController (Trading)

- (void)updateRiskLabels {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    BOOL enabled = [defaults boolForKey:@"risk_controls_enabled"];
    self.riskEnabledSwitch.on = enabled;

    NSString *stopLoss = [defaults stringForKey:@"risk_stop_loss"];
    NSString *takeProfit = [defaults stringForKey:@"risk_take_profit"];

    NSString *stopText = (stopLoss.length > 0) ? [NSString stringWithFormat:@"%@%%", stopLoss] : @"--";
    NSString *takeText = (takeProfit.length > 0) ? [NSString stringWithFormat:@"%@%%", takeProfit] : @"--";

    if (!enabled) {
        self.riskStopLabel.text = @"Stop Loss: disabled";
        self.riskTakeLabel.text = @"Take Profit: disabled";
    } else {
        self.riskStopLabel.text = [NSString stringWithFormat:@"Stop Loss: %@", stopText];
        self.riskTakeLabel.text = [NSString stringWithFormat:@"Take Profit: %@", takeText];
    }
}

- (void)riskSwitchChanged {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setBool:self.riskEnabledSwitch.isOn forKey:@"risk_controls_enabled"];
    [defaults synchronize];
    [self updateRiskLabels];
}

- (void)configureRisk {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Risk Targets"
                                                                   message:@"Set stop loss and take profit targets (percentage)."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Stop Loss % (e.g. 3)";
        field.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Take Profit % (e.g. 6)";
        field.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *stopLoss = alert.textFields.firstObject.text ?: @"";
        NSString *takeProfit = alert.textFields.count > 1 ? (alert.textFields[1].text ?: @"") : @"";
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        if (stopLoss.length > 0) {
            [defaults setObject:stopLoss forKey:@"risk_stop_loss"];
        } else {
            [defaults removeObjectForKey:@"risk_stop_loss"];
        }
        if (takeProfit.length > 0) {
            [defaults setObject:takeProfit forKey:@"risk_take_profit"];
        } else {
            [defaults removeObjectForKey:@"risk_take_profit"];
        }
        [defaults setBool:YES forKey:@"risk_controls_enabled"];
        [defaults synchronize];
        [self updateRiskLabels];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (NSString *)currentStrategyName {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *strategy = [defaults stringForKey:@"openrouter_strategy"] ?: @"balanced";
    if ([strategy isEqualToString:@"conservative"]) {
        return @"Conservative";
    }
    if ([strategy isEqualToString:@"aggressive"]) {
        return @"Aggressive";
    }
    if ([strategy isEqualToString:@"custom"]) {
        return @"Custom";
    }
    return @"Balanced";
}

- (void)updateStrategyLabel {
    self.aiStrategyLabel.text = [NSString stringWithFormat:@"Strategy: %@", [self currentStrategyName]];
}

- (NSString *)actionFromDecision:(NSString *)decision {
    if (decision.length == 0) {
        return nil;
    }
    NSString *upper = [decision uppercaseString];
    if ([upper containsString:@"BUY"]) {
        return @"BUY";
    }
    if ([upper containsString:@"SELL"]) {
        return @"SELL";
    }
    return nil;
}

- (void)maybeAutoTradeWithAction:(NSString *)action {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults boolForKey:@"openrouter_auto_trade"]) {
        return;
    }
    NSString *sizeText = [defaults stringForKey:@"openrouter_trade_size"] ?: @"";
    NSDecimalNumber *size = [NSDecimalNumber decimalNumberWithString:sizeText];
    if ([size compare:[NSDecimalNumber zero]] != NSOrderedDescending) {
        return;
    }
    if (action.length == 0 || [action isEqualToString:@"HOLD"]) {
        return;
    }
    if (self.lastAITradeAt && [[NSDate date] timeIntervalSinceDate:self.lastAITradeAt] < 60) {
        return;
    }

    self.lastAITradeAt = [NSDate date];
    NSString *journalEntryId = self.lastJournalEntryId;

    [[TACoinbaseAPI sharedInstance] createOrder:self.selectedSymbol
                                           side:action
                                           size:size
                                     completion:^(TAOrder *order, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self showToast:[NSString stringWithFormat:@"AI trade failed: %@", error.localizedDescription]];
                // Update journal with failed status
                if (journalEntryId) {
                    TATradeJournal *entry = [[TAJournalStorage sharedInstance] getEntry:journalEntryId];
                    if (entry) {
                        entry.orderStatus = @"FAILED";
                        entry.notes = error.localizedDescription;
                        [[TAJournalStorage sharedInstance] updateEntry:entry];
                    }
                }
                return;
            }
            self.lastOrderId = order.orderId;
            [self showToast:[NSString stringWithFormat:@"AI %@ order placed", action]];

            // Update journal with order details
            if (journalEntryId) {
                TATradeJournal *entry = [[TAJournalStorage sharedInstance] getEntry:journalEntryId];
                if (entry) {
                    entry.orderId = order.orderId;
                    entry.side = [action lowercaseString];
                    entry.size = size;
                    entry.entryPrice = self.latestPrice.length > 0 ? [NSDecimalNumber decimalNumberWithString:self.latestPrice] : nil;
                    entry.orderStatus = order.status ?: @"PENDING";
                    [[TAJournalStorage sharedInstance] updateEntry:entry];
                }
            }

            [self refreshData];
        });
    }];
}

- (void)maybeRequestAIRecommendationWithAccounts:(NSArray<NSDictionary *> *)accounts {
    if (!self.isTrading) {
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *openRouterKey = [defaults stringForKey:@"openrouter_api_key"];
    if (openRouterKey.length == 0) {
        self.aiDecisionLabel.text = @"AI Signal: set OpenRouter key";
        self.aiConfidenceLabel.text = @"Confidence: --";
        self.aiConfidenceBar.progress = 0.0;
        return;
    }
    if (self.lastAIRequestAt && [[NSDate date] timeIntervalSinceDate:self.lastAIRequestAt] < 30) {
        return;
    }
    self.lastAIRequestAt = [NSDate date];
    NSString *price = self.latestPrice ?: @"--";

    [[TAOpenRouterClient sharedInstance] requestRecommendationForSymbol:self.selectedSymbol
                                                                 price:price
                                                               accounts:accounts ?: @[]
                                                             completion:^(NSDictionary *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                self.aiDecisionLabel.text = [NSString stringWithFormat:@"AI Signal: %@", error.localizedDescription];
                return;
            }
            NSString *raw = response[@"raw"] ?: @"";
            NSString *action = response[@"action"];
            NSString *rationale = response[@"rationale"] ?: @"";
            NSNumber *confidence = response[@"confidence"];

            if (action.length == 0) {
                action = [self actionFromDecision:raw] ?: @"HOLD";
            }
            NSString *summary = action;
            if (rationale.length > 0) {
                summary = [NSString stringWithFormat:@"%@ — %@", action, rationale];
            }
            if (summary.length > 120) {
                summary = [[summary substringToIndex:120] stringByAppendingString:@"…"];
            }
            self.aiDecisionLabel.text = [NSString stringWithFormat:@"AI Signal: %@", summary];

            double confidenceValue = confidence ? confidence.doubleValue : 0.0;
            if (confidenceValue < 0.0) confidenceValue = 0.0;
            if (confidenceValue > 100.0) confidenceValue = 100.0;
            self.aiConfidenceLabel.text = [NSString stringWithFormat:@"Confidence: %.0f%%", confidenceValue];
            self.aiConfidenceBar.progress = (float)(confidenceValue / 100.0);

            self.lastAISignal = raw.length > 0 ? raw : summary;
            self.lastJournalEntryId = response[@"journalEntryId"];
            if ([action isEqualToString:@"BUY"] || [action isEqualToString:@"SELL"]) {
                [self maybeAutoTradeWithAction:action];
            }
        });
    }];
}

- (void)timeframeChanged {
    [self refreshData];
}

- (void)toggleTrading {
    if (![TACoinbaseAPI sharedInstance].isConfigured) {
        [self openSettings];
        return;
    }
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *openRouterKey = [defaults stringForKey:@"openrouter_api_key"];
    NSString *model = [defaults stringForKey:@"openrouter_model"];
    if (openRouterKey.length == 0 || model.length == 0) {
        [self showToast:@"Configure OpenRouter key and model"];
        [self openSettings];
        return;
    }

    self.isTrading = !self.isTrading;

    if (self.isTrading) {
        [self.tradeButton setTitle:@"⏹ STOP AI TRADING" forState:UIControlStateNormal];
        self.tradeButton.backgroundColor = [UIColor colorWithRed:0.9 green:0.2 blue:0.2 alpha:1.0];
        [self startTrading];
    } else {
        [self.tradeButton setTitle:@"▶ START AI TRADING" forState:UIControlStateNormal];
        self.tradeButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.3 alpha:1.0];
        [self stopTrading];
    }
}

- (void)startTrading {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSString *model = [defaults stringForKey:@"openrouter_model"] ?: @"(not set)";
    NSString *strategy = [self currentStrategyName];
    BOOL riskEnabled = [defaults boolForKey:@"risk_controls_enabled"];
    NSString *stopLoss = [defaults stringForKey:@"risk_stop_loss"] ?: @"--";
    NSString *takeProfit = [defaults stringForKey:@"risk_take_profit"] ?: @"--";
    NSString *riskText = riskEnabled ? [NSString stringWithFormat:@"Risk: SL %@%% / TP %@%%", stopLoss, takeProfit] : @"Risk: disabled";

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"AI Trading Active"
                                                                   message:[NSString stringWithFormat:@"Model: %@\nStrategy: %@\nProvider: OpenRouter\n%@\n\nMonitoring %@.", model, strategy, riskText, self.selectedSymbol]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    self.aiDecisionLabel.text = @"AI Signal: fetching…";
    self.aiConfidenceLabel.text = @"Confidence: --";
    self.aiConfidenceBar.progress = 0.0;
}

- (void)stopTrading {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Trading Paused"
                                                                   message:@"AI trading is paused."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
    self.aiDecisionLabel.text = @"AI Signal: --";
    self.aiConfidenceLabel.text = @"Confidence: --";
    self.aiConfidenceBar.progress = 0.0;
}

- (void)placeOrder {
    if (![TACoinbaseAPI sharedInstance].isConfigured) {
        [self openSettings];
        return;
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Place Market Order"
                                                                   message:@"This will place a real order using your API key."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.placeholder = @"Size (quote for BUY / base for SELL)";
        field.keyboardType = UIKeyboardTypeDecimalPad;
    }];

    [alert addAction:[UIAlertAction actionWithTitle:@"BUY" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *sizeText = alert.textFields.firstObject.text ?: @"0";
        [self submitOrderWithSide:@"BUY" size:sizeText];
    }]];

    [alert addAction:[UIAlertAction actionWithTitle:@"SELL" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *sizeText = alert.textFields.firstObject.text ?: @"0";
        [self submitOrderWithSide:@"SELL" size:sizeText];
    }]];

    if (self.lastOrderId.length > 0) {
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel Last Order" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [[TACoinbaseAPI sharedInstance] cancelOrder:self.lastOrderId completion:^(BOOL success, NSError *error) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSString *msg = success ? @"Last order cancelled" : (error.localizedDescription ?: @"Cancel failed");
                    [self showToast:msg];
                });
            }];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)submitOrderWithSide:(NSString *)side size:(NSString *)sizeText {
    NSDecimalNumber *size = [NSDecimalNumber decimalNumberWithString:sizeText ?: @"0"];
    if ([size compare:[NSDecimalNumber zero]] != NSOrderedDescending) {
        [self showToast:@"Enter a valid size"];
        return;
    }

    [[TACoinbaseAPI sharedInstance] createOrder:self.selectedSymbol side:side size:size completion:^(TAOrder *order, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                [self showToast:error.localizedDescription];
                return;
            }
            self.lastOrderId = order.orderId;
            [self showToast:[NSString stringWithFormat:@"Order %@ placed", order.orderId ?: @"created"]];
            [self refreshData];
        });
    }];
}

- (void)showToast:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@""
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:alert animated:YES completion:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [alert dismissViewControllerAnimated:YES completion:nil];
    });
}

- (void)openSettings {
    if (self.tabBarController) {
        NSArray *controllers = self.tabBarController.viewControllers;
        NSInteger targetIndex = NSNotFound;
        for (NSInteger i = 0; i < controllers.count; i++) {
            UIViewController *vc = controllers[i];
            UIViewController *root = vc;
            if ([vc isKindOfClass:[UINavigationController class]]) {
                root = ((UINavigationController *)vc).viewControllers.firstObject;
            }
            if ([root isKindOfClass:[TASettingsViewController class]]) {
                targetIndex = i;
                break;
            }
        }
        if (targetIndex != NSNotFound) {
            self.tabBarController.selectedIndex = targetIndex;
            return;
        }
    }

    TASettingsViewController *settings = [[TASettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:settings];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)selectSymbol {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Select Trading Pair"
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleActionSheet];

    for (NSString *symbol in self.symbols) {
        [alert addAction:[UIAlertAction actionWithTitle:symbol style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
            self.selectedSymbol = symbol;
            [self.symbolButton setTitle:[NSString stringWithFormat:@"%@ ▼", symbol] forState:UIControlStateNormal];
            [self refreshData];
        }]];
    }

    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

