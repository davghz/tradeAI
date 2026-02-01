/**
 * TACoinbaseAPI+Accounts.mm
 */

#import "TACoinbaseAPI+Private.h"

@implementation TACoinbaseAPI (Accounts)

static NSArray<NSDictionary *> *TAJWTAuthCombos(void) {
    static NSArray<NSDictionary *> *combos = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        combos = @[
            @{@"mode": @"https", @"full": @YES},
            @{@"mode": @"host", @"full": @YES},
            @{@"mode": @"path", @"full": @YES},
            @{@"mode": @"https", @"full": @NO},
            @{@"mode": @"host", @"full": @NO},
            @{@"mode": @"path", @"full": @NO}
        ];
    });
    return combos;
}

static NSString *TAStringFromBalanceValue(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value stringValue];
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)value;
        id inner = dict[@"value"] ?: dict[@"amount"] ?: dict[@"balance"];
        if ([inner isKindOfClass:[NSNumber class]]) {
            return [(NSNumber *)inner stringValue];
        }
        if ([inner isKindOfClass:[NSString class]]) {
            return (NSString *)inner;
        }
    }
    return @"0";
}

static NSString *TAStringFromCurrencyValue(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)value;
        id inner = dict[@"currency"] ?: dict[@"code"] ?: dict[@"symbol"];
        if ([inner isKindOfClass:[NSString class]]) {
            return (NSString *)inner;
        }
    }
    return @"";
}

static NSString *TAStringFromBalanceCurrency(id value) {
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)value;
        id currencyValue = dict[@"currency"];
        if ([currencyValue isKindOfClass:[NSString class]]) {
            return (NSString *)currencyValue;
        }
        return TAStringFromCurrencyValue(currencyValue);
    }
    return @"";
}

- (void)getAccounts:(void (^)(NSArray<TAAccount *> *accounts, NSError *error))completion {
    [self getAccountsAttempt:0 completion:completion];
}

- (void)getAccountsAttempt:(NSInteger)attempt completion:(void (^)(NSArray<TAAccount *> *accounts, NSError *error))completion {
    if (![self isConfigured]) {
        completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:401
                                        userInfo:@{NSLocalizedDescriptionKey: @"ECDSA credentials not configured"}]);
        return;
    }

    NSArray<NSDictionary *> *combos = TAJWTAuthCombos();
    if (attempt < combos.count) {
        NSDictionary *combo = combos[attempt];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:combo[@"mode"] forKey:@"coinbase_jwt_uri_mode"];
        [defaults setBool:[combo[@"full"] boolValue] forKey:@"coinbase_ecdsa_use_full_name"];
        [defaults synchronize];
    }

    NSError *jwtError = nil;
    NSMutableURLRequest *request = [self createAuthRequest:@"/accounts" method:@"GET" body:nil error:&jwtError];
    if (!request) {
        completion(nil, jwtError ?: [NSError errorWithDomain:@"CoinbaseAPI" code:401
                                                   userInfo:@{NSLocalizedDescriptionKey: @"JWT generation failed"}]);
        return;
    }

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }

            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                if (httpResponse.statusCode == 401 && attempt + 1 < combos.count) {
                    [self getAccountsAttempt:attempt + 1 completion:completion];
                    return;
                }
                NSString *bodyText = data.length > 0 ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : @"";
                if (bodyText.length > 200) {
                    bodyText = [bodyText substringToIndex:200];
                }
                NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
                [defaults setObject:@(httpResponse.statusCode) forKey:@"debug_accounts_status"];
                if (bodyText.length > 0) {
                    [defaults setObject:bodyText forKey:@"debug_accounts_body"];
                } else {
                    [defaults removeObjectForKey:@"debug_accounts_body"];
                }
                [defaults synchronize];
                NSString *errorMsg = [NSString stringWithFormat:@"HTTP %ld - Check API credentials%@", (long)httpResponse.statusCode,
                                      (bodyText.length > 0 ? [NSString stringWithFormat:@": %@", bodyText] : @"")];
                completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:httpResponse.statusCode
                                                userInfo:@{NSLocalizedDescriptionKey: errorMsg}]);
                return;
            }

            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (!json || jsonError) {
                completion(nil, jsonError ?: [NSError errorWithDomain:@"CoinbaseAPI" code:500
                                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid accounts response"}]);
                return;
            }

            NSArray *accountsData = json[@"accounts"] ?: @[];
            NSMutableArray<TAAccount *> *accounts = [NSMutableArray array];
            for (NSDictionary *acc in accountsData) {
                TAAccount *account = [[TAAccount alloc] init];
                account.accountId = acc[@"uuid"] ?: acc[@"account_id"];
                account.name = acc[@"name"];
                account.currency = TAStringFromCurrencyValue(acc[@"currency"]);
                id availableBalance = acc[@"available_balance"] ?: acc[@"available"];
                id totalBalance = acc[@"total_balance"] ?: acc[@"total"];
                account.available = [NSDecimalNumber decimalNumberWithString:TAStringFromBalanceValue(availableBalance)];
                account.hold = [NSDecimalNumber decimalNumberWithString:TAStringFromBalanceValue(acc[@"hold"])];
                account.total = [NSDecimalNumber decimalNumberWithString:TAStringFromBalanceValue(totalBalance)];
                account.availableCurrency = TAStringFromBalanceCurrency(availableBalance);
                account.totalCurrency = TAStringFromBalanceCurrency(totalBalance);
                [accounts addObject:account];
            }
            completion(accounts, nil);
        });
    }];

    [task resume];
}

- (void)getAccount:(NSString *)accountId completion:(void (^)(TAAccount *account, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:@"/accounts/%@", accountId];
    NSError *jwtError = nil;
    NSMutableURLRequest *request = [self createAuthRequest:path method:@"GET" body:nil error:&jwtError];
    if (!request) {
        completion(nil, jwtError ?: [NSError errorWithDomain:@"CoinbaseAPI" code:401
                                                   userInfo:@{NSLocalizedDescriptionKey: @"JWT generation failed"}]);
        return;
    }

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }

            NSError *jsonError;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];

            TAAccount *account = [[TAAccount alloc] init];
            account.accountId = json[@"uuid"];
            account.currency = json[@"currency"];

            completion(account, nil);
        });
    }];

    [task resume];
}

@end
