/**
 * TACoinbaseAPI+Market.mm
 */

#import "TACoinbaseAPI+Private.h"

@implementation TACoinbaseAPI (Market)

static NSString *TAStringFromValue(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value stringValue];
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)value;
        id inner = dict[@"value"] ?: dict[@"amount"] ?: dict[@"price"] ?: dict[@"size"] ?: dict[@"volume"] ?: dict[@"percent"] ?: dict[@"percentage"];
        if ([inner isKindOfClass:[NSNumber class]]) {
            return [(NSNumber *)inner stringValue];
        }
        if ([inner isKindOfClass:[NSString class]]) {
            return (NSString *)inner;
        }
    }
    return nil;
}

static NSDictionary *TANormalizeOrderBookEntry(id entry) {
    if ([entry isKindOfClass:[NSDictionary class]]) {
        NSMutableDictionary *dict = [(NSDictionary *)entry mutableCopy];
        NSString *price = TAStringFromValue(dict[@"price"] ?: dict[@"px"]);
        if (price.length > 0) {
            dict[@"price"] = price;
        }
        NSString *size = TAStringFromValue(dict[@"size"] ?: dict[@"qty"]);
        if (size.length > 0) {
            dict[@"size"] = size;
        }
        return dict;
    }
    if ([entry isKindOfClass:[NSArray class]]) {
        NSArray *array = (NSArray *)entry;
        NSString *price = array.count > 0 ? TAStringFromValue(array[0]) : nil;
        NSString *size = array.count > 1 ? TAStringFromValue(array[1]) : nil;
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        if (price.length > 0) {
            dict[@"price"] = price;
        }
        if (size.length > 0) {
            dict[@"size"] = size;
        }
        return dict;
    }
    return @{};
}

- (void)getServerTime:(void (^)(NSDate *serverTime, NSError *error))completion {
    NSString *urlString = [NSString stringWithFormat:@"%@/time", self.baseURL];
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }

            NSError *jsonError;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            NSDictionary *dict = [json isKindOfClass:[NSDictionary class]] ? (NSDictionary *)json : nil;

            if (dict[@"epoch"]) {
                NSTimeInterval epoch = [dict[@"epoch"] doubleValue];
                completion([NSDate dateWithTimeIntervalSince1970:epoch], nil);
            } else {
                completion([NSDate date], nil);
            }
        });
    }];

    [task resume];
}

- (void)getProducts:(void (^)(NSArray *products, NSError *error))completion {
    NSMutableURLRequest *request = [self createRequest:@"/market/products" method:@"GET" body:nil requiresAuth:NO];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = [NSString stringWithFormat:@"HTTP %ld - Failed to load products", (long)httpResponse.statusCode];
                completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:httpResponse.statusCode
                                                userInfo:@{NSLocalizedDescriptionKey: errorMsg}]);
                return;
            }

            NSError *jsonError;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (!json || jsonError) {
                completion(nil, jsonError ?: [NSError errorWithDomain:@"CoinbaseAPI" code:500
                                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid products response"}]);
                return;
            }
            if (![json isKindOfClass:[NSDictionary class]]) {
                completion(@[], nil);
                return;
            }
            NSDictionary *dict = (NSDictionary *)json;
            NSArray *products = dict[@"products"] ?: @[];
            if (![products isKindOfClass:[NSArray class]]) {
                completion(@[], nil);
                return;
            }
            NSMutableArray *normalized = [NSMutableArray array];
            NSArray<NSString *> *keys = @[
                @"price", @"price_usd", @"price_percentage_change_24h",
                @"change_24h", @"high_24h", @"low_24h", @"volume_24h", @"volume"
            ];
            for (id entry in products) {
                if (![entry isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                NSMutableDictionary *product = [(NSDictionary *)entry mutableCopy];
                for (NSString *key in keys) {
                    NSString *value = TAStringFromValue(product[key]);
                    if (value.length > 0) {
                        product[key] = value;
                    }
                }
                [normalized addObject:product];
            }
            completion(normalized, nil);
        });
    }];

    [task resume];
}

- (void)getProduct:(NSString *)productId completion:(void (^)(NSDictionary *product, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:@"/market/products/%@", productId];
    NSMutableURLRequest *request = [self createRequest:path method:@"GET" body:nil requiresAuth:NO];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = [NSString stringWithFormat:@"HTTP %ld - Failed to load product", (long)httpResponse.statusCode];
                completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:httpResponse.statusCode
                                                userInfo:@{NSLocalizedDescriptionKey: errorMsg}]);
                return;
            }

            NSError *jsonError;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (!json || jsonError) {
                completion(nil, jsonError ?: [NSError errorWithDomain:@"CoinbaseAPI" code:500
                                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid product response"}]);
                return;
            }
            if (![json isKindOfClass:[NSDictionary class]]) {
                completion(@{}, nil);
                return;
            }
            NSMutableDictionary *normalized = [(NSDictionary *)json mutableCopy];
            NSArray<NSString *> *keys = @[
                @"price", @"price_usd", @"price_percentage_change_24h",
                @"high_24h", @"low_24h", @"volume_24h", @"volume"
            ];
            NSDictionary *product = json[@"product"];
            if ([product isKindOfClass:[NSDictionary class]]) {
                NSMutableDictionary *productDict = [(NSDictionary *)product mutableCopy];
                for (NSString *key in keys) {
                    NSString *value = TAStringFromValue(productDict[key]);
                    if (value.length > 0) {
                        productDict[key] = value;
                    }
                }
                normalized[@"product"] = productDict;
            } else {
                for (NSString *key in keys) {
                    NSString *value = TAStringFromValue(normalized[key]);
                    if (value.length > 0) {
                        normalized[key] = value;
                    }
                }
            }
            completion(normalized, nil);
        });
    }];

    [task resume];
}

- (void)getBestBidAsk:(NSArray<NSString *> *)productIds completion:(void (^)(NSDictionary *data, NSError *error))completion {
    NSString *productId = productIds.firstObject ?: @"";
    NSString *path = [NSString stringWithFormat:@"/market/product_book?product_id=%@", productId];
    NSMutableURLRequest *request = [self createRequest:path method:@"GET" body:nil requiresAuth:NO];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = [NSString stringWithFormat:@"HTTP %ld - Failed to load bid/ask", (long)httpResponse.statusCode];
                completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:httpResponse.statusCode
                                                userInfo:@{NSLocalizedDescriptionKey: errorMsg}]);
                return;
            }

            NSError *jsonError;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (!json || jsonError) {
                completion(nil, jsonError ?: [NSError errorWithDomain:@"CoinbaseAPI" code:500
                                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid product book response"}]);
                return;
            }
            if (![json isKindOfClass:[NSDictionary class]]) {
                completion(@{}, nil);
                return;
            }
            NSMutableDictionary *normalized = [(NSDictionary *)json mutableCopy];
            id pricebook = normalized[@"pricebook"];
            if ([pricebook isKindOfClass:[NSDictionary class]]) {
                NSMutableDictionary *bookDict = [(NSDictionary *)pricebook mutableCopy];
                id bidsObj = bookDict[@"bids"];
                id asksObj = bookDict[@"asks"];
                if ([bidsObj isKindOfClass:[NSArray class]]) {
                    NSMutableArray *bids = [NSMutableArray array];
                    for (id entry in (NSArray *)bidsObj) {
                        [bids addObject:TANormalizeOrderBookEntry(entry)];
                    }
                    bookDict[@"bids"] = bids;
                } else if (bidsObj) {
                    bookDict[@"bids"] = @[TANormalizeOrderBookEntry(bidsObj)];
                }
                if ([asksObj isKindOfClass:[NSArray class]]) {
                    NSMutableArray *asks = [NSMutableArray array];
                    for (id entry in (NSArray *)asksObj) {
                        [asks addObject:TANormalizeOrderBookEntry(entry)];
                    }
                    bookDict[@"asks"] = asks;
                } else if (asksObj) {
                    bookDict[@"asks"] = @[TANormalizeOrderBookEntry(asksObj)];
                }
                normalized[@"pricebook"] = bookDict;
            } else if ([normalized[@"pricebooks"] isKindOfClass:[NSArray class]]) {
                NSMutableArray *books = [NSMutableArray array];
                for (id book in (NSArray *)normalized[@"pricebooks"]) {
                    if (![book isKindOfClass:[NSDictionary class]]) {
                        continue;
                    }
                    NSMutableDictionary *bookDict = [(NSDictionary *)book mutableCopy];
                    id bidsObj = bookDict[@"bids"];
                    id asksObj = bookDict[@"asks"];
                    if ([bidsObj isKindOfClass:[NSArray class]]) {
                        NSMutableArray *bids = [NSMutableArray array];
                        for (id entry in (NSArray *)bidsObj) {
                            [bids addObject:TANormalizeOrderBookEntry(entry)];
                        }
                        bookDict[@"bids"] = bids;
                    }
                    if ([asksObj isKindOfClass:[NSArray class]]) {
                        NSMutableArray *asks = [NSMutableArray array];
                        for (id entry in (NSArray *)asksObj) {
                            [asks addObject:TANormalizeOrderBookEntry(entry)];
                        }
                        bookDict[@"asks"] = asks;
                    }
                    [books addObject:bookDict];
                }
                normalized[@"pricebooks"] = books;
            }
            completion(normalized, nil);
        });
    }];

    [task resume];
}

- (void)getProductCandles:(NSString *)productId granularity:(NSString *)granularity completion:(void (^)(NSArray *candles, NSError *error))completion {
    // Default to 1 hour candles if not specified
    NSString *gran = granularity ?: @"ONE_HOUR";
    NSDate *now = [NSDate date];
    NSTimeInterval window = 60 * 60;
    if ([gran isEqualToString:@"ONE_MINUTE"]) {
        window = 60 * 60;
    } else if ([gran isEqualToString:@"FIFTEEN_MINUTE"]) {
        window = 60 * 60 * 24;
    } else if ([gran isEqualToString:@"ONE_HOUR"]) {
        window = 60 * 60 * 24 * 7;
    } else if ([gran isEqualToString:@"ONE_DAY"]) {
        window = 60 * 60 * 24 * 30;
    }
    long long end = (long long)llround([now timeIntervalSince1970]);
    long long start = end - (long long)window;
    NSString *path = [NSString stringWithFormat:@"/market/products/%@/candles?granularity=%@&start=%lld&end=%lld&limit=200", productId, gran, start, end];
    NSMutableURLRequest *request = [self createRequest:path method:@"GET" body:nil requiresAuth:NO];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = [NSString stringWithFormat:@"HTTP %ld - Failed to load candles", (long)httpResponse.statusCode];
                completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:httpResponse.statusCode
                                                userInfo:@{NSLocalizedDescriptionKey: errorMsg}]);
                return;
            }

            NSError *jsonError;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (!json || jsonError) {
                completion(nil, jsonError ?: [NSError errorWithDomain:@"CoinbaseAPI" code:500
                                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid candles response"}]);
                return;
            }

            id rawCandles = nil;
            if ([json isKindOfClass:[NSDictionary class]]) {
                rawCandles = ((NSDictionary *)json)[@"candles"] ?: ((NSDictionary *)json)[@"data"];
            } else if ([json isKindOfClass:[NSArray class]]) {
                rawCandles = json;
            }

            if (![rawCandles isKindOfClass:[NSArray class]]) {
                completion(@[], nil);
                return;
            }

            NSMutableArray *normalized = [NSMutableArray array];
            for (id entry in (NSArray *)rawCandles) {
                if ([entry isKindOfClass:[NSDictionary class]]) {
                    NSMutableDictionary *dict = [(NSDictionary *)entry mutableCopy];
                    NSString *start = TAStringFromValue(dict[@"start"] ?: dict[@"time"]);
                    NSString *open = TAStringFromValue(dict[@"open"] ?: dict[@"open_price"]);
                    NSString *high = TAStringFromValue(dict[@"high"] ?: dict[@"high_price"]);
                    NSString *low = TAStringFromValue(dict[@"low"] ?: dict[@"low_price"]);
                    NSString *close = TAStringFromValue(dict[@"close"] ?: dict[@"close_price"] ?: dict[@"price"]);
                    NSString *volume = TAStringFromValue(dict[@"volume"] ?: dict[@"volume_24h"]);
                    if (start.length > 0) dict[@"start"] = start;
                    if (open.length > 0) dict[@"open"] = open;
                    if (high.length > 0) dict[@"high"] = high;
                    if (low.length > 0) dict[@"low"] = low;
                    if (close.length > 0) dict[@"close"] = close;
                    if (volume.length > 0) dict[@"volume"] = volume;
                    [normalized addObject:dict];
                } else if ([entry isKindOfClass:[NSArray class]]) {
                    NSArray *arr = (NSArray *)entry;
                    NSString *start = arr.count > 0 ? TAStringFromValue(arr[0]) : nil;
                    NSString *low = arr.count > 1 ? TAStringFromValue(arr[1]) : nil;
                    NSString *high = arr.count > 2 ? TAStringFromValue(arr[2]) : nil;
                    NSString *open = arr.count > 3 ? TAStringFromValue(arr[3]) : nil;
                    NSString *close = arr.count > 4 ? TAStringFromValue(arr[4]) : nil;
                    NSString *volume = arr.count > 5 ? TAStringFromValue(arr[5]) : nil;
                    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
                    if (start.length > 0) dict[@"start"] = start;
                    if (open.length > 0) dict[@"open"] = open;
                    if (high.length > 0) dict[@"high"] = high;
                    if (low.length > 0) dict[@"low"] = low;
                    if (close.length > 0) dict[@"close"] = close;
                    if (volume.length > 0) dict[@"volume"] = volume;
                    [normalized addObject:dict];
                }
            }

            completion(normalized, nil);
        });
    }];

    [task resume];
}

- (void)getMarketTrades:(NSString *)productId completion:(void (^)(NSArray *trades, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:@"/market/products/%@/ticker?limit=10", productId];
    NSMutableURLRequest *request = [self createRequest:path method:@"GET" body:nil requiresAuth:NO];
    [request setValue:@"no-cache" forHTTPHeaderField:@"Cache-Control"];

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error) {
                completion(nil, error);
                return;
            }
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            if (httpResponse.statusCode != 200) {
                NSString *errorMsg = [NSString stringWithFormat:@"HTTP %ld - Failed to load trades", (long)httpResponse.statusCode];
                completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:httpResponse.statusCode
                                                userInfo:@{NSLocalizedDescriptionKey: errorMsg}]);
                return;
            }

            NSError *jsonError;
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (!json || jsonError) {
                completion(nil, jsonError ?: [NSError errorWithDomain:@"CoinbaseAPI" code:500
                                                            userInfo:@{NSLocalizedDescriptionKey: @"Invalid trades response"}]);
                return;
            }
            NSDictionary *dict = [json isKindOfClass:[NSDictionary class]] ? (NSDictionary *)json : nil;
            NSArray *trades = dict ? dict[@"trades"] : nil;
            if (!trades && json[@"price"]) {
                trades = @[@{ @"price": json[@"price"] ?: @"--",
                              @"size": json[@"size"] ?: json[@"volume"] ?: @"--",
                              @"side": json[@"side"] ?: @"--" }];
            }
            if ([trades isKindOfClass:[NSArray class]]) {
                NSMutableArray *normalized = [NSMutableArray array];
                for (id entry in trades) {
                    if (![entry isKindOfClass:[NSDictionary class]]) {
                        continue;
                    }
                    NSDictionary *trade = (NSDictionary *)entry;
                    NSMutableDictionary *mapped = [trade mutableCopy];
                    NSString *price = TAStringFromValue(trade[@"price"]);
                    if (price.length > 0) {
                        mapped[@"price"] = price;
                    }
                    NSString *size = TAStringFromValue(trade[@"size"] ?: trade[@"volume"]);
                    if (size.length > 0) {
                        mapped[@"size"] = size;
                    }
                    NSString *side = TAStringFromValue(trade[@"side"] ?: trade[@"trade_side"]);
                    if (side.length > 0) {
                        mapped[@"side"] = side;
                    }
                    [normalized addObject:mapped];
                }
                completion(normalized, nil);
            } else {
                completion(@[], nil);
            }
        });
    }];

    [task resume];
}

@end
