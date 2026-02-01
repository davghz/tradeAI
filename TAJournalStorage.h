/**
 * TAJournalStorage.h
 * JSON file-based persistence for trade journal entries
 */

#import <Foundation/Foundation.h>
#import "TATradeJournal.h"

@interface TAJournalStorage : NSObject

+ (instancetype)sharedInstance;

// CRUD Operations
- (void)saveEntry:(TATradeJournal *)entry;
- (void)updateEntry:(TATradeJournal *)entry;
- (void)deleteEntry:(NSString *)entryId;
- (TATradeJournal *)getEntry:(NSString *)entryId;

// Fetch Operations
- (NSArray<TATradeJournal *> *)fetchAllEntries;
- (NSArray<TATradeJournal *> *)fetchEntriesForSymbol:(NSString *)symbol;
- (NSArray<TATradeJournal *> *)fetchEntriesFromDate:(NSDate *)startDate toDate:(NSDate *)endDate;
- (NSArray<TATradeJournal *> *)fetchOpenTrades;  // Entries without exitPrice

// Export
- (NSString *)exportToCSV;
- (NSURL *)exportToCSVFile;

// Statistics
- (NSDictionary *)calculateStatistics;

@end
