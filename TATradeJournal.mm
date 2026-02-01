/**
 * TATradeJournal.mm
 */

#import "TATradeJournal.h"

@implementation TATradeJournal

+ (instancetype)entryWithSymbol:(NSString *)symbol {
    TATradeJournal *entry = [[TATradeJournal alloc] init];
    entry.entryId = [[NSUUID UUID] UUIDString];
    entry.timestamp = [NSDate date];
    entry.symbol = symbol;
    return entry;
}

#pragma mark - NSCoding

- (void)encodeWithCoder:(NSCoder *)coder {
    [coder encodeObject:self.entryId forKey:@"entryId"];
    [coder encodeObject:self.timestamp forKey:@"timestamp"];
    [coder encodeObject:self.symbol forKey:@"symbol"];
    [coder encodeObject:self.priceAtDecision forKey:@"priceAtDecision"];
    [coder encodeObject:self.aiModel forKey:@"aiModel"];
    [coder encodeObject:self.aiStrategy forKey:@"aiStrategy"];
    [coder encodeObject:self.aiAction forKey:@"aiAction"];
    [coder encodeObject:self.aiConfidence forKey:@"aiConfidence"];
    [coder encodeObject:self.aiRationale forKey:@"aiRationale"];
    [coder encodeObject:self.orderId forKey:@"orderId"];
    [coder encodeObject:self.side forKey:@"side"];
    [coder encodeObject:self.size forKey:@"size"];
    [coder encodeObject:self.entryPrice forKey:@"entryPrice"];
    [coder encodeObject:self.orderStatus forKey:@"orderStatus"];
    [coder encodeObject:self.exitPrice forKey:@"exitPrice"];
    [coder encodeObject:self.exitTime forKey:@"exitTime"];
    [coder encodeObject:self.pnl forKey:@"pnl"];
    [coder encodeObject:self.pnlPercent forKey:@"pnlPercent"];
    [coder encodeObject:self.exitReason forKey:@"exitReason"];
    [coder encodeObject:self.notes forKey:@"notes"];
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super init];
    if (self) {
        _entryId = [coder decodeObjectForKey:@"entryId"];
        _timestamp = [coder decodeObjectForKey:@"timestamp"];
        _symbol = [coder decodeObjectForKey:@"symbol"];
        _priceAtDecision = [coder decodeObjectForKey:@"priceAtDecision"];
        _aiModel = [coder decodeObjectForKey:@"aiModel"];
        _aiStrategy = [coder decodeObjectForKey:@"aiStrategy"];
        _aiAction = [coder decodeObjectForKey:@"aiAction"];
        _aiConfidence = [coder decodeObjectForKey:@"aiConfidence"];
        _aiRationale = [coder decodeObjectForKey:@"aiRationale"];
        _orderId = [coder decodeObjectForKey:@"orderId"];
        _side = [coder decodeObjectForKey:@"side"];
        _size = [coder decodeObjectForKey:@"size"];
        _entryPrice = [coder decodeObjectForKey:@"entryPrice"];
        _orderStatus = [coder decodeObjectForKey:@"orderStatus"];
        _exitPrice = [coder decodeObjectForKey:@"exitPrice"];
        _exitTime = [coder decodeObjectForKey:@"exitTime"];
        _pnl = [coder decodeObjectForKey:@"pnl"];
        _pnlPercent = [coder decodeObjectForKey:@"pnlPercent"];
        _exitReason = [coder decodeObjectForKey:@"exitReason"];
        _notes = [coder decodeObjectForKey:@"notes"];
    }
    return self;
}

#pragma mark - Dictionary Conversion

- (NSDictionary *)toDictionary {
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];

    if (self.entryId) dict[@"entryId"] = self.entryId;
    if (self.timestamp) dict[@"timestamp"] = @([self.timestamp timeIntervalSince1970]);
    if (self.symbol) dict[@"symbol"] = self.symbol;
    if (self.priceAtDecision) dict[@"priceAtDecision"] = self.priceAtDecision.stringValue;
    if (self.aiModel) dict[@"aiModel"] = self.aiModel;
    if (self.aiStrategy) dict[@"aiStrategy"] = self.aiStrategy;
    if (self.aiAction) dict[@"aiAction"] = self.aiAction;
    if (self.aiConfidence) dict[@"aiConfidence"] = self.aiConfidence;
    if (self.aiRationale) dict[@"aiRationale"] = self.aiRationale;
    if (self.orderId) dict[@"orderId"] = self.orderId;
    if (self.side) dict[@"side"] = self.side;
    if (self.size) dict[@"size"] = self.size.stringValue;
    if (self.entryPrice) dict[@"entryPrice"] = self.entryPrice.stringValue;
    if (self.orderStatus) dict[@"orderStatus"] = self.orderStatus;
    if (self.exitPrice) dict[@"exitPrice"] = self.exitPrice.stringValue;
    if (self.exitTime) dict[@"exitTime"] = @([self.exitTime timeIntervalSince1970]);
    if (self.pnl) dict[@"pnl"] = self.pnl.stringValue;
    if (self.pnlPercent) dict[@"pnlPercent"] = self.pnlPercent.stringValue;
    if (self.exitReason) dict[@"exitReason"] = self.exitReason;
    if (self.notes) dict[@"notes"] = self.notes;

    return dict;
}

+ (instancetype)fromDictionary:(NSDictionary *)dict {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;

    TATradeJournal *entry = [[TATradeJournal alloc] init];

    entry.entryId = dict[@"entryId"];

    id ts = dict[@"timestamp"];
    if ([ts respondsToSelector:@selector(doubleValue)]) {
        entry.timestamp = [NSDate dateWithTimeIntervalSince1970:[ts doubleValue]];
    }

    entry.symbol = dict[@"symbol"];

    NSString *priceStr = dict[@"priceAtDecision"];
    if (priceStr.length > 0) {
        entry.priceAtDecision = [NSDecimalNumber decimalNumberWithString:priceStr];
    }

    entry.aiModel = dict[@"aiModel"];
    entry.aiStrategy = dict[@"aiStrategy"];
    entry.aiAction = dict[@"aiAction"];
    entry.aiConfidence = dict[@"aiConfidence"];
    entry.aiRationale = dict[@"aiRationale"];
    entry.orderId = dict[@"orderId"];
    entry.side = dict[@"side"];

    NSString *sizeStr = dict[@"size"];
    if (sizeStr.length > 0) {
        entry.size = [NSDecimalNumber decimalNumberWithString:sizeStr];
    }

    NSString *entryPriceStr = dict[@"entryPrice"];
    if (entryPriceStr.length > 0) {
        entry.entryPrice = [NSDecimalNumber decimalNumberWithString:entryPriceStr];
    }

    entry.orderStatus = dict[@"orderStatus"];

    NSString *exitPriceStr = dict[@"exitPrice"];
    if (exitPriceStr.length > 0) {
        entry.exitPrice = [NSDecimalNumber decimalNumberWithString:exitPriceStr];
    }

    id exitTs = dict[@"exitTime"];
    if ([exitTs respondsToSelector:@selector(doubleValue)]) {
        entry.exitTime = [NSDate dateWithTimeIntervalSince1970:[exitTs doubleValue]];
    }

    NSString *pnlStr = dict[@"pnl"];
    if (pnlStr.length > 0) {
        entry.pnl = [NSDecimalNumber decimalNumberWithString:pnlStr];
    }

    NSString *pnlPctStr = dict[@"pnlPercent"];
    if (pnlPctStr.length > 0) {
        entry.pnlPercent = [NSDecimalNumber decimalNumberWithString:pnlPctStr];
    }

    entry.exitReason = dict[@"exitReason"];
    entry.notes = dict[@"notes"];

    return entry;
}

@end
