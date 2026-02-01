/**
 * TASettingsViewController+Persistence.mm
 */

#import "TASettingsViewController+Private.h"
#import "TACoinbaseAPI.h"

@implementation TASettingsViewController (Persistence)

- (void)loadSettings {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    // ECDSA credentials
    self.apiKeyField.text = [defaults stringForKey:@"coinbase_api_key"];
    self.privateKeyField.text = [defaults stringForKey:@"coinbase_private_key"];
    // Ed25519 credentials
    self.ed25519ApiKeyField.text = [defaults stringForKey:@"coinbase_ed25519_api_key"];
    self.ed25519PrivateKeyField.text = [defaults stringForKey:@"coinbase_ed25519_private_key"];
    // OpenRouter settings
    self.openRouterKeyField.text = [defaults stringForKey:@"openrouter_api_key"];
    self.modelField.text = [defaults stringForKey:@"openrouter_model"];
    NSString *strategy = [defaults stringForKey:@"openrouter_strategy"] ?: @"balanced";
    if ([strategy isEqualToString:@"conservative"]) {
        self.strategyControl.selectedSegmentIndex = 0;
    } else if ([strategy isEqualToString:@"aggressive"]) {
        self.strategyControl.selectedSegmentIndex = 2;
    } else if ([strategy isEqualToString:@"custom"]) {
        self.strategyControl.selectedSegmentIndex = 3;
    } else {
        self.strategyControl.selectedSegmentIndex = 1;
    }
    self.customPromptField.text = [defaults stringForKey:@"openrouter_custom_prompt"];
    [self strategyChanged];
    self.autoTradeSwitch.on = [defaults boolForKey:@"openrouter_auto_trade"];
    self.tradeSizeField.text = [defaults stringForKey:@"openrouter_trade_size"];
}

- (void)saveSettings {
    [self.view endEditing:YES];
    NSString *apiKey = [self.apiKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *privateKey = [self.privateKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *ed25519ApiKey = [self.ed25519ApiKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *ed25519PrivateKey = [self.ed25519PrivateKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    BOOL hasECDSA = (apiKey.length > 0 && privateKey.length > 0);
    BOOL hasEd25519 = (ed25519ApiKey.length > 0 && ed25519PrivateKey.length > 0);

    // Validate ECDSA credentials if partially entered
    if ((apiKey.length > 0 || privateKey.length > 0) && !hasECDSA) {
        [self showAlert:@"Error" message:@"Please enter both ECDSA API Key name and Private Key, or leave both empty."];
        return;
    }

    if (hasECDSA) {
        // Validate API Key name format (organizations/.../apiKeys/...)
        if (![self isValidAPIKeyName:apiKey]) {
            [self showAlert:@"Invalid API Key Format"
                     message:@"API Key must be in format:\n\norganizations/{org_id}/apiKeys/{key_id}\n\nExample:\norganizations/12345678-1234-1234-1234-123456789012/apiKeys/87654321-4321-4321-4321-210987654321\n\nCopy the API key *name* from the portal."];
            return;
        }

        // Validate private key format (PEM/base64)
        if (privateKey.length < 40) {
            [self showAlert:@"Invalid Private Key"
                     message:@"Private key should be the PEM block or base64 value from the downloaded key file."];
            return;
        }
    }

    // Validate Ed25519 credentials if partially entered
    if ((ed25519ApiKey.length > 0 || ed25519PrivateKey.length > 0) && !hasEd25519) {
        [self showAlert:@"Error" message:@"Please enter both Ed25519 API Key ID and Private Key, or leave both empty."];
        return;
    }

    if (hasEd25519) {
        // Validate Ed25519 key ID format (UUID)
        if (![self isValidUUIDFormat:ed25519ApiKey]) {
            [self showAlert:@"Invalid Ed25519 Key ID"
                     message:@"Ed25519 API Key ID should be a UUID format:\n\nxxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"];
            return;
        }

        // Validate Ed25519 private key (should be base64, ~88 chars for 64 bytes)
        if (ed25519PrivateKey.length < 40) {
            [self showAlert:@"Invalid Ed25519 Private Key"
                     message:@"Ed25519 private key should be base64 encoded (64 bytes)."];
            return;
        }
    }

    // Save to UserDefaults
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

    // Save ECDSA credentials
    if (hasECDSA) {
        [defaults setObject:apiKey forKey:@"coinbase_api_key"];
        [defaults setObject:privateKey forKey:@"coinbase_private_key"];
    } else {
        [defaults removeObjectForKey:@"coinbase_api_key"];
        [defaults removeObjectForKey:@"coinbase_private_key"];
    }

    // Save Ed25519 credentials
    if (hasEd25519) {
        [defaults setObject:ed25519ApiKey forKey:@"coinbase_ed25519_api_key"];
        [defaults setObject:ed25519PrivateKey forKey:@"coinbase_ed25519_private_key"];
    } else {
        [defaults removeObjectForKey:@"coinbase_ed25519_api_key"];
        [defaults removeObjectForKey:@"coinbase_ed25519_private_key"];
    }

    // Save OpenRouter settings
    NSString *openRouterKey = [self.openRouterKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (openRouterKey.length > 0) {
        [defaults setObject:openRouterKey forKey:@"openrouter_api_key"];
    } else {
        [defaults removeObjectForKey:@"openrouter_api_key"];
    }
    NSString *model = [self.modelField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (model.length > 0) {
        [defaults setObject:model forKey:@"openrouter_model"];
    } else {
        [defaults removeObjectForKey:@"openrouter_model"];
    }
    NSString *strategyValue = @"balanced";
    switch (self.strategyControl.selectedSegmentIndex) {
        case 0: strategyValue = @"conservative"; break;
        case 2: strategyValue = @"aggressive"; break;
        case 3: strategyValue = @"custom"; break;
        default: strategyValue = @"balanced"; break;
    }
    [defaults setObject:strategyValue forKey:@"openrouter_strategy"];
    NSString *customPrompt = [self.customPromptField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (customPrompt.length > 0) {
        [defaults setObject:customPrompt forKey:@"openrouter_custom_prompt"];
    } else {
        [defaults removeObjectForKey:@"openrouter_custom_prompt"];
    }
    [defaults setBool:self.autoTradeSwitch.isOn forKey:@"openrouter_auto_trade"];
    NSString *tradeSize = [self.tradeSizeField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (tradeSize.length > 0) {
        [defaults setObject:tradeSize forKey:@"openrouter_trade_size"];
    } else {
        [defaults removeObjectForKey:@"openrouter_trade_size"];
    }
    [defaults synchronize];

    // Configure API with credentials
    TACoinbaseAPI *api = [TACoinbaseAPI sharedInstance];

    if (hasECDSA) {
        [api setAPIKey:apiKey apiPrivateKey:privateKey];
    }

    if (hasEd25519) {
        [api setEd25519APIKey:ed25519ApiKey ed25519PrivateKey:ed25519PrivateKey];
    }

    // Show success message
    NSMutableString *message = [NSMutableString stringWithString:@"Settings saved!\n"];
    if (hasECDSA) {
        [message appendFormat:@"\n✅ ECDSA: %@", apiKey];
    }
    if (hasEd25519) {
        [message appendFormat:@"\n✅ Ed25519: %@", ed25519ApiKey];
    }
    if (!hasECDSA && !hasEd25519) {
        [message appendString:@"\n⚠️ No API credentials configured"];
    }
    [self showAlert:@"✅ Saved" message:message];
}

- (void)strategyChanged {
    BOOL isCustom = (self.strategyControl.selectedSegmentIndex == 3);
    self.customPromptField.enabled = isCustom;
    self.customPromptField.alpha = isCustom ? 1.0 : 0.5;
}

- (BOOL)isValidAPIKeyName:(NSString *)apiKeyName {
    NSString *prefix = @"organizations/";
    NSString *segment = @"/apiKeys/";
    if (![apiKeyName hasPrefix:prefix]) {
        return NO;
    }
    NSRange segmentRange = [apiKeyName rangeOfString:segment];
    if (segmentRange.location == NSNotFound) {
        return NO;
    }
    NSString *orgId = [apiKeyName substringWithRange:NSMakeRange(prefix.length, segmentRange.location - prefix.length)];
    NSString *keyId = [apiKeyName substringFromIndex:segmentRange.location + segment.length];
    return ([self isValidUUIDFormat:orgId] && [self isValidUUIDFormat:keyId]);
}

- (BOOL)isValidUUIDFormat:(NSString *)uuid {
    // UUID format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx (36 characters)
    if (uuid.length != 36) {
        return NO;
    }

    // Check for dashes at correct positions
    // Format: 8-4-4-4-12 characters
    if ([uuid characterAtIndex:8] != '-' ||
        [uuid characterAtIndex:13] != '-' ||
        [uuid characterAtIndex:18] != '-' ||
        [uuid characterAtIndex:23] != '-') {
        return NO;
    }

    // Check that all other characters are valid hex digits
    NSCharacterSet *hexChars = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    for (NSUInteger i = 0; i < uuid.length; i++) {
        if (i == 8 || i == 13 || i == 18 || i == 23) {
            continue; // Skip dash positions
        }
        unichar c = [uuid characterAtIndex:i];
        if (![hexChars characterIsMember:c]) {
            return NO;
        }
    }

    return YES;
}

- (void)testConnection {
    TACoinbaseAPI *api = [TACoinbaseAPI sharedInstance];

    if (!api.isConfigured) {
        [self showAlert:@"Not Configured" message:@"Please save your API credentials first."];
        return;
    }

    // Show loading
    UIAlertController *loading = [UIAlertController alertControllerWithTitle:@"Testing API Connection"
                                                                     message:@"Signing request with ECDSA..."
                                                              preferredStyle:UIAlertControllerStyleAlert];
    [self presentViewController:loading animated:YES completion:nil];

    // Test server time first (public endpoint)
    [api getServerTime:^(NSDate *serverTime, NSError *error) {
        if (error) {
            [loading dismissViewControllerAnimated:YES completion:^{
                [self showAlert:@"Connection Failed" message:[NSString stringWithFormat:@"Could not reach Coinbase API: %@", error.localizedDescription]];
            }];
            return;
        }

        // Test authenticated endpoint
        [api getAccounts:^(NSArray<TAAccount *> *accounts, NSError *error) {
            [loading dismissViewControllerAnimated:YES completion:^{
                if (error) {
                    NSString *errorMsg = error.localizedDescription;
                    if ([errorMsg containsString:@"401"]) {
                        errorMsg = @"Authentication failed.\n\nPlease check:\n• API Key format\n• Private Key is correct\n• Key has 'view' permission";
                    }
                    [self showAlert:@"Auth Failed" message:errorMsg];
                } else {
                    NSDecimalNumber *total = [NSDecimalNumber zero];
                    for (TAAccount *acc in accounts) {
                        total = [total decimalNumberByAdding:acc.total];
                    }
                    [self showAlert:@"Connection Successful!"
                             message:[NSString stringWithFormat:@"✅ Server time: %@\n✅ Authentication working\n✅ Retrieved %lu accounts\n✅ Total balance: $%.2f",
                                     serverTime, (unsigned long)accounts.count, [total doubleValue]]];
                }
            }];
        }];
    }];
}

- (void)showAlert:(NSString *)title message:(NSString *)message {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end

