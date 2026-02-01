/**
 * TACoinbaseAPI.h
 * Coinbase Advanced Trade API v3 with ECDSA + Ed25519 Authentication
 * https://docs.cdp.coinbase.com/coinbase-app/advanced-trade-apis/rest-api
 */

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface TAOrder : NSObject
@property (nonatomic, copy) NSString *orderId;
@property (nonatomic, copy) NSString *clientOrderId;
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, copy) NSString *side;
@property (nonatomic, strong) NSDecimalNumber *size;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, copy) NSString *status;
@property (nonatomic, strong) NSDate *createdAt;
@end

@interface TAAccount : NSObject
@property (nonatomic, copy) NSString *accountId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, copy) NSString *availableCurrency;
@property (nonatomic, copy) NSString *totalCurrency;
@property (nonatomic, strong) NSDecimalNumber *available;
@property (nonatomic, strong) NSDecimalNumber *hold;
@property (nonatomic, strong) NSDecimalNumber *total;
@end

@interface TAMarketData : NSObject
@property (nonatomic, copy) NSString *productId;
@property (nonatomic, strong) NSDecimalNumber *price;
@property (nonatomic, strong) NSDecimalNumber *volume24h;
@property (nonatomic, strong) NSDecimalNumber *change24h;
@property (nonatomic, strong) NSDecimalNumber *high24h;
@property (nonatomic, strong) NSDecimalNumber *low24h;
@end

@interface TACoinbaseAPI : NSObject

+ (instancetype)sharedInstance;

// Configuration - ECDSA (ES256) Key Pair
- (void)setAPIKey:(NSString *)apiKey apiPrivateKey:(NSString *)privateKey;

// Configuration - Ed25519 (EdDSA) Key Pair
- (void)setEd25519APIKey:(NSString *)apiKey ed25519PrivateKey:(NSString *)privateKey;

@property (nonatomic, readonly) BOOL isConfigured;

// Accounts - GET /api/v3/brokerage/accounts
- (void)getAccounts:(void (^)(NSArray<TAAccount *> *accounts, NSError *error))completion;
- (void)getAccount:(NSString *)accountId completion:(void (^)(TAAccount *account, NSError *error))completion;

// Products/Market Data - Public Endpoints
- (void)getProducts:(void (^)(NSArray *products, NSError *error))completion;
- (void)getProduct:(NSString *)productId completion:(void (^)(NSDictionary *product, NSError *error))completion;
- (void)getProductCandles:(NSString *)productId granularity:(NSString *)granularity completion:(void (^)(NSArray *candles, NSError *error))completion;
- (void)getMarketTrades:(NSString *)productId completion:(void (^)(NSArray *trades, NSError *error))completion;

// Best Bid/Ask - GET /api/v3/brokerage/best_bid_ask
- (void)getBestBidAsk:(NSArray<NSString *> *)productIds completion:(void (^)(NSDictionary *data, NSError *error))completion;

// Orders - Authenticated
- (void)createOrder:(NSString *)productId side:(NSString *)side size:(NSDecimalNumber *)size 
         completion:(void (^)(TAOrder *order, NSError *error))completion;
- (void)listOrders:(void (^)(NSArray<TAOrder *> *orders, NSError *error))completion;
- (void)getOrder:(NSString *)orderId completion:(void (^)(TAOrder *order, NSError *error))completion;
- (void)cancelOrder:(NSString *)orderId completion:(void (^)(BOOL success, NSError *error))completion;

// Server Time - GET /api/v3/brokerage/time
- (void)getServerTime:(void (^)(NSDate *serverTime, NSError *error))completion;

@end

NS_ASSUME_NONNULL_END
