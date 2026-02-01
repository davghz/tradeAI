/**
 * TAJournalStorage.mm
 */

#import "TAJournalStorage.h"

@interface TAJournalStorage ()
@property (nonatomic, strong) NSMutableArray<TATradeJournal *> *entries;
@property (nonatomic, copy) NSString *storagePath;
@end

@implementation TAJournalStorage

+ (instancetype)sharedInstance {
    static TAJournalStorage *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDir = paths.firstObject;
        _storagePath = [documentsDir stringByAppendingPathComponent:@"trade_journal.json"];
        [self loadFromDisk];
    }
    return self;
}

#pragma mark - Persistence

- (void)loadFromDisk {
    self.entries = [NSMutableArray array];

    if (![[NSFileManager defaultManager] fileExistsAtPath:self.storagePath]) {
        return;
    }

    NSData *data = [NSData dataWithContentsOfFile:self.storagePath];
    if (!data) return;

    NSError *error = nil;
    NSArray *jsonArray = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    if (error || ![jsonArray isKindOfClass:[NSArray class]]) return;

    for (NSDictionary *dict in jsonArray) {
        TATradeJournal *entry = [TATradeJournal fromDictionary:dict];
        if (entry) {
            [self.entries addObject:entry];
        }
    }

    // Sort by timestamp descending (newest first)
    [self.entries sortUsingComparator:^NSComparisonResult(TATradeJournal *a, TATradeJournal *b) {
        return [b.timestamp compare:a.timestamp];
    }];
}

- (void)saveToDisk {
    NSMutableArray *jsonArray = [NSMutableArray arrayWithCapacity:self.entries.count];
    for (TATradeJournal *entry in self.entries) {
        [jsonArray addObject:[entry toDictionary]];
    }

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:jsonArray options:NSJSONWritingPrettyPrinted error:&error];
    if (!error && data) {
        [data writeToFile:self.storagePath atomically:YES];
    }
}

#pragma mark - CRUD Operations

- (void)saveEntry:(TATradeJournal *)entry {
    if (!entry || !entry.entryId) return;

    // Check for existing entry with same ID
    NSUInteger index = [self.entries indexOfObjectPassingTest:^BOOL(TATradeJournal *obj, NSUInteger idx, BOOL *stop) {
        return [obj.entryId isEqualToString:entry.entryId];
    }];

    if (index != NSNotFound) {
        [self.entries replaceObjectAtIndex:index withObject:entry];
    } else {
        [self.entries insertObject:entry atIndex:0];  // Insert at beginning (newest first)
    }

    [self saveToDisk];
}

- (void)updateEntry:(TATradeJournal *)entry {
    [self saveEntry:entry];
}

- (void)deleteEntry:(NSString *)entryId {
    if (!entryId) return;

    NSUInteger index = [self.entries indexOfObjectPassingTest:^BOOL(TATradeJournal *obj, NSUInteger idx, BOOL *stop) {
        return [obj.entryId isEqualToString:entryId];
    }];

    if (index != NSNotFound) {
        [self.entries removeObjectAtIndex:index];
        [self saveToDisk];
    }
}

- (TATradeJournal *)getEntry:(NSString *)entryId {
    if (!entryId) return nil;

    for (TATradeJournal *entry in self.entries) {
        if ([entry.entryId isEqualToString:entryId]) {
            return entry;
        }
    }
    return nil;
}

#pragma mark - Fetch Operations

- (NSArray<TATradeJournal *> *)fetchAllEntries {
    return [self.entries copy];
}

- (NSArray<TATradeJournal *> *)fetchEntriesForSymbol:(NSString *)symbol {
    if (!symbol) return @[];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"symbol == %@", symbol];
    return [self.entries filteredArrayUsingPredicate:predicate];
}

- (NSArray<TATradeJournal *> *)fetchEntriesFromDate:(NSDate *)startDate toDate:(NSDate *)endDate {
    if (!startDate || !endDate) return @[];

    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"timestamp >= %@ AND timestamp <= %@", startDate, endDate];
    return [self.entries filteredArrayUsingPredicate:predicate];
}

- (NSArray<TATradeJournal *> *)fetchOpenTrades {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"exitPrice == nil AND orderId != nil"];
    return [self.entries filteredArrayUsingPredicate:predicate];
}

#pragma mark - Export

- (NSString *)exportToCSV {
    NSMutableString *csv = [NSMutableString string];

    // Header row
    [csv appendString:@"Entry ID,Timestamp,Symbol,AI Model,AI Strategy,AI Action,AI Confidence,"];
    [csv appendString:@"Order ID,Side,Size,Entry Price,Exit Price,Exit Time,PnL,PnL %,Exit Reason,Notes\n"];

    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";

    for (TATradeJournal *entry in self.entries) {
        NSString *timestamp = entry.timestamp ? [dateFormatter stringFromDate:entry.timestamp] : @"";
        NSString *exitTime = entry.exitTime ? [dateFormatter stringFromDate:entry.exitTime] : @"";

        // Escape fields that might contain commas or quotes
        NSString *rationale = [self escapeCSVField:entry.aiRationale];
        NSString *notes = [self escapeCSVField:entry.notes];

        [csv appendFormat:@"%@,%@,%@,%@,%@,%@,%@,",
            entry.entryId ?: @"",
            timestamp,
            entry.symbol ?: @"",
            entry.aiModel ?: @"",
            entry.aiStrategy ?: @"",
            entry.aiAction ?: @"",
            entry.aiConfidence ?: @""];

        [csv appendFormat:@"%@,%@,%@,%@,%@,%@,%@,%@,%@,%@\n",
            entry.orderId ?: @"",
            entry.side ?: @"",
            entry.size.stringValue ?: @"",
            entry.entryPrice.stringValue ?: @"",
            entry.exitPrice.stringValue ?: @"",
            exitTime,
            entry.pnl.stringValue ?: @"",
            entry.pnlPercent.stringValue ?: @"",
            entry.exitReason ?: @"",
            notes];
    }

    return csv;
}

- (NSString *)escapeCSVField:(NSString *)field {
    if (!field) return @"";
    if ([field containsString:@","] || [field containsString:@"\""] || [field containsString:@"\n"]) {
        NSString *escaped = [field stringByReplacingOccurrencesOfString:@"\"" withString:@"\"\""];
        return [NSString stringWithFormat:@"\"%@\"", escaped];
    }
    return field;
}

- (NSURL *)exportToCSVFile {
    NSString *csv = [self exportToCSV];
    if (!csv) return nil;

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDir = paths.firstObject;

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"yyyy-MM-dd_HHmmss";
    NSString *filename = [NSString stringWithFormat:@"trade_journal_%@.csv", [formatter stringFromDate:[NSDate date]]];

    NSString *filePath = [documentsDir stringByAppendingPathComponent:filename];
    NSError *error = nil;
    [csv writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];

    if (error) return nil;
    return [NSURL fileURLWithPath:filePath];
}

#pragma mark - Statistics

- (NSDictionary *)calculateStatistics {
    NSMutableDictionary *stats = [NSMutableDictionary dictionary];

    NSArray *closedTrades = [self.entries filteredArrayUsingPredicate:
        [NSPredicate predicateWithFormat:@"exitPrice != nil AND entryPrice != nil"]];

    stats[@"totalTrades"] = @(self.entries.count);
    stats[@"closedTrades"] = @(closedTrades.count);
    stats[@"openTrades"] = @([self fetchOpenTrades].count);

    if (closedTrades.count == 0) {
        stats[@"winRate"] = @0;
        stats[@"totalPnL"] = @0;
        stats[@"avgPnL"] = @0;
        stats[@"avgPnLPercent"] = @0;
        return stats;
    }

    NSInteger wins = 0;
    NSDecimalNumber *totalPnL = [NSDecimalNumber zero];
    NSDecimalNumber *totalPnLPercent = [NSDecimalNumber zero];

    for (TATradeJournal *entry in closedTrades) {
        if (entry.pnl && [entry.pnl compare:[NSDecimalNumber zero]] == NSOrderedDescending) {
            wins++;
        }
        if (entry.pnl) {
            totalPnL = [totalPnL decimalNumberByAdding:entry.pnl];
        }
        if (entry.pnlPercent) {
            totalPnLPercent = [totalPnLPercent decimalNumberByAdding:entry.pnlPercent];
        }
    }

    double winRate = (double)wins / (double)closedTrades.count * 100.0;
    double avgPnL = totalPnL.doubleValue / closedTrades.count;
    double avgPnLPercent = totalPnLPercent.doubleValue / closedTrades.count;

    stats[@"wins"] = @(wins);
    stats[@"losses"] = @(closedTrades.count - wins);
    stats[@"winRate"] = @(winRate);
    stats[@"totalPnL"] = @(totalPnL.doubleValue);
    stats[@"avgPnL"] = @(avgPnL);
    stats[@"avgPnLPercent"] = @(avgPnLPercent);

    return stats;
}

@end
