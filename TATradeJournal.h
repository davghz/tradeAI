/**
 * TATradeJournal.h
 * Trade journal entry model for logging AI decisions and trade outcomes
 */

#import <Foundation/Foundation.h>

@interface TATradeJournal : NSObject <NSCoding>

// Identification
@property (nonatomic, copy) NSString *entryId;
@property (nonatomic, strong) NSDate *timestamp;

// Market Context
@property (nonatomic, copy) NSString *symbol;
@property (nonatomic, strong) NSDecimalNumber *priceAtDecision;

// AI Decision Context
@property (nonatomic, copy) NSString *aiModel;
@property (nonatomic, copy) NSString *aiStrategy;
@property (nonatomic, copy) NSString *aiAction;        // BUY, SELL, HOLD
@property (nonatomic, strong) NSNumber *aiConfidence;  // 0-100
@property (nonatomic, copy) NSString *aiRationale;

// Trade Execution
@property (nonatomic, copy) NSString *orderId;
@property (nonatomic, copy) NSString *side;            // buy, sell
@property (nonatomic, strong) NSDecimalNumber *size;
@property (nonatomic, strong) NSDecimalNumber *entryPrice;
@property (nonatomic, copy) NSString *orderStatus;     // pending, filled, cancelled, failed

// Trade Outcome (filled after exit)
@property (nonatomic, strong) NSDecimalNumber *exitPrice;
@property (nonatomic, strong) NSDate *exitTime;
@property (nonatomic, strong) NSDecimalNumber *pnl;
@property (nonatomic, strong) NSDecimalNumber *pnlPercent;
@property (nonatomic, copy) NSString *exitReason;      // ai_signal, stop_loss, take_profit, manual
@property (nonatomic, copy) NSString *notes;

// Convenience initializers
+ (instancetype)entryWithSymbol:(NSString *)symbol;
- (NSDictionary *)toDictionary;
+ (instancetype)fromDictionary:(NSDictionary *)dict;

@end
