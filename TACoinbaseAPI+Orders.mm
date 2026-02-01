/**
 * TACoinbaseAPI+Orders.mm
 */

#import "TACoinbaseAPI+Private.h"
#import "TATradeJournal.h"
#import "TAJournalStorage.h"

@implementation TACoinbaseAPI (Orders)

static NSString *TAOrderStringFromValue(id value) {
    if ([value isKindOfClass:[NSString class]]) {
        return (NSString *)value;
    }
    if ([value isKindOfClass:[NSNumber class]]) {
        return [(NSNumber *)value stringValue];
    }
    if ([value isKindOfClass:[NSDictionary class]]) {
        NSDictionary *dict = (NSDictionary *)value;
        id inner = dict[@"value"] ?: dict[@"amount"] ?: dict[@"id"] ?: dict[@"side"] ?: dict[@"status"];
        if ([inner isKindOfClass:[NSString class]]) {
            return (NSString *)inner;
        }
        if ([inner isKindOfClass:[NSNumber class]]) {
            return [(NSNumber *)inner stringValue];
        }
    }
    return nil;
}

- (void)createOrder:(NSString *)productId side:(NSString *)side size:(NSDecimalNumber *)size
         completion:(void (^)(TAOrder *order, NSError *error))completion {
    if (![self isConfigured]) {
        completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:401
                                        userInfo:@{NSLocalizedDescriptionKey: @"ECDSA credentials not configured"}]);
        return;
    }

    NSString *clientOrderId = [[NSUUID UUID] UUIDString];

    NSDictionary *bodyDict = @{
        @"client_order_id": clientOrderId,
        @"product_id": productId,
        @"side": [side lowercaseString],
        @"order_configuration": @{
            @"market_market_ioc": @{
                @"base_size": [side isEqualToString:@"SELL"] ? [size stringValue] : [NSNull null],
                @"quote_size": [side isEqualToString:@"BUY"] ? [size stringValue] : [NSNull null]
            }
        }
    };

    NSError *jsonError;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
    NSString *bodyString = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];

    NSError *jwtError = nil;
    NSMutableURLRequest *request = [self createAuthRequest:@"/orders" method:@"POST" body:bodyString error:&jwtError];
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
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            NSDictionary *dict = [json isKindOfClass:[NSDictionary class]] ? (NSDictionary *)json : nil;

            TAOrder *order = [[TAOrder alloc] init];
            order.clientOrderId = clientOrderId;
            order.orderId = dict ? (dict[@"success_response"][@"order_id"] ?: clientOrderId) : clientOrderId;
            order.productId = productId;
            order.side = side;
            order.size = size;
            order.createdAt = [NSDate date];
            order.status = @"PENDING";

            NSLog(@"[CoinbaseAPI] Order created via ECDSA: %@ %@ %@", side, size, productId);
            completion(order, nil);
        });
    }];

    [task resume];
}

- (void)listOrders:(void (^)(NSArray<TAOrder *> *orders, NSError *error))completion {
    if (![self isConfigured]) {
        completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:401
                                        userInfo:@{NSLocalizedDescriptionKey: @"ECDSA credentials not configured"}]);
        return;
    }

    NSError *jwtError = nil;
    NSMutableURLRequest *request = [self createAuthRequest:@"/orders/historical/batch" method:@"GET" body:nil error:&jwtError];
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
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError) {
                completion(nil, jsonError);
                return;
            }
            if (![json isKindOfClass:[NSDictionary class]]) {
                completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:500
                                               userInfo:@{NSLocalizedDescriptionKey: @"Invalid orders response"}]);
                return;
            }
            NSDictionary *dict = (NSDictionary *)json;

            NSMutableArray<TAOrder *> *orders = [NSMutableArray array];
            for (NSDictionary *ord in dict[@"orders"] ?: @[]) {
                if (![ord isKindOfClass:[NSDictionary class]]) {
                    continue;
                }
                TAOrder *order = [[TAOrder alloc] init];
                order.orderId = TAOrderStringFromValue(ord[@"order_id"] ?: ord[@"id"]);
                order.productId = TAOrderStringFromValue(ord[@"product_id"]);
                NSString *side = TAOrderStringFromValue(ord[@"side"]);
                order.side = side.length > 0 ? [side uppercaseString] : nil;
                order.status = TAOrderStringFromValue(ord[@"status"]);
                [orders addObject:order];
            }

            completion(orders, nil);
        });
    }];

    [task resume];
}

- (void)getOrder:(NSString *)orderId completion:(void (^)(TAOrder *order, NSError *error))completion {
    NSString *path = [NSString stringWithFormat:@"/orders/historical/%@", orderId];
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
            id json = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonError];
            if (jsonError) {
                completion(nil, jsonError);
                return;
            }
            if (![json isKindOfClass:[NSDictionary class]]) {
                completion(nil, [NSError errorWithDomain:@"CoinbaseAPI" code:500
                                               userInfo:@{NSLocalizedDescriptionKey: @"Invalid order response"}]);
                return;
            }
            NSDictionary *dict = (NSDictionary *)json;

            TAOrder *order = [[TAOrder alloc] init];
            order.orderId = TAOrderStringFromValue(dict[@"order_id"] ?: dict[@"id"]);
            order.productId = TAOrderStringFromValue(dict[@"product_id"]);
            order.status = TAOrderStringFromValue(dict[@"status"]);

            completion(order, nil);
        });
    }];

    [task resume];
}

- (void)cancelOrder:(NSString *)orderId completion:(void (^)(BOOL success, NSError *error))completion {
    NSDictionary *bodyDict = @{
        @"order_ids": @[orderId]
    };

    NSError *jsonError;
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:bodyDict options:0 error:&jsonError];
    NSString *bodyString = [[NSString alloc] initWithData:bodyData encoding:NSUTF8StringEncoding];

    NSError *jwtError = nil;
    NSMutableURLRequest *request = [self createAuthRequest:@"/orders/batch_cancel" method:@"POST" body:bodyString error:&jwtError];
    if (!request) {
        completion(NO, jwtError ?: [NSError errorWithDomain:@"CoinbaseAPI" code:401
                                                  userInfo:@{NSLocalizedDescriptionKey: @"JWT generation failed"}]);
        return;
    }

    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
            completion(httpResponse.statusCode == 200, error);
        });
    }];

    [task resume];
}

@end
