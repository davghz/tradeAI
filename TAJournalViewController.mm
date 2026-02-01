/**
 * TAJournalViewController.mm
 */

#import "TAJournalViewController.h"
#import "TATradeJournal.h"
#import "TAJournalStorage.h"
#import "TAGlassCardView.h"
#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

@interface TAJournalViewController () <UITableViewDelegate, UITableViewDataSource>
@property (nonatomic, strong) CAGradientLayer *gradientLayer;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIView *statsCard;
@property (nonatomic, strong) UILabel *statsLabel;
@property (nonatomic, strong) UISegmentedControl *filterControl;
@property (nonatomic, strong) UIButton *exportButton;
@property (nonatomic, strong) NSArray<TATradeJournal *> *entries;
@property (nonatomic, copy) NSString *currentFilter;
@end

@implementation TAJournalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"Trade Journal";
    self.view.backgroundColor = [UIColor blackColor];
    self.currentFilter = @"all";

    [self setupUI];
    [self refreshData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self refreshData];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.gradientLayer.frame = self.view.bounds;

    CGFloat width = self.view.bounds.size.width;
    CGFloat margin = 16;
    CGFloat y = 16;

    // Stats card
    self.statsCard.frame = CGRectMake(margin, y, width - margin * 2, 80);
    self.statsLabel.frame = CGRectMake(16, 12, self.statsCard.bounds.size.width - 32, 56);
    y += 96;

    // Filter control
    self.filterControl.frame = CGRectMake(margin, y, width - margin * 2 - 80, 32);
    self.exportButton.frame = CGRectMake(width - margin - 70, y, 70, 32);
    y += 48;

    // Table view
    self.tableView.frame = CGRectMake(0, y, width, self.view.bounds.size.height - y);
}

- (void)setupUI {
    self.gradientLayer = [CAGradientLayer layer];
    self.gradientLayer.colors = @[(id)[UIColor colorWithRed:0.05 green:0.06 blue:0.10 alpha:1.0].CGColor,
                                  (id)[UIColor colorWithRed:0.02 green:0.03 blue:0.05 alpha:1.0].CGColor];
    self.gradientLayer.startPoint = CGPointMake(0, 0);
    self.gradientLayer.endPoint = CGPointMake(1, 1);
    [self.view.layer insertSublayer:self.gradientLayer atIndex:0];

    // Stats card
    self.statsCard = [[TAGlassCardView alloc] initWithFrame:CGRectZero];
    [self.view addSubview:self.statsCard];

    self.statsLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.statsLabel.textColor = [UIColor whiteColor];
    self.statsLabel.font = [UIFont systemFontOfSize:13];
    self.statsLabel.numberOfLines = 0;
    self.statsLabel.text = @"Loading stats...";
    [self.statsCard addSubview:self.statsLabel];

    // Filter control
    self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"All", @"Wins", @"Losses", @"Open"]];
    self.filterControl.selectedSegmentIndex = 0;
    self.filterControl.tintColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.7 alpha:1.0];
    [self.filterControl addTarget:self action:@selector(filterChanged) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.filterControl];

    // Export button
    self.exportButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.exportButton setTitle:@"Export" forState:UIControlStateNormal];
    [self.exportButton setTitleColor:[UIColor colorWithRed:0.2 green:0.9 blue:0.7 alpha:1.0] forState:UIControlStateNormal];
    self.exportButton.titleLabel.font = [UIFont systemFontOfSize:13 weight:UIFontWeightSemibold];
    [self.exportButton addTarget:self action:@selector(exportTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.exportButton];

    // Table view
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorColor = [UIColor colorWithWhite:0.2 alpha:1.0];
    self.tableView.rowHeight = UITableViewAutomaticDimension;
    self.tableView.estimatedRowHeight = 100;
    [self.tableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"JournalCell"];
    [self.view addSubview:self.tableView];
}

- (void)refreshData {
    // Fetch entries based on filter
    NSArray<TATradeJournal *> *allEntries = [[TAJournalStorage sharedInstance] fetchAllEntries];

    if ([self.currentFilter isEqualToString:@"wins"]) {
        self.entries = [allEntries filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"pnl != nil AND pnl > 0"]];
    } else if ([self.currentFilter isEqualToString:@"losses"]) {
        self.entries = [allEntries filteredArrayUsingPredicate:
            [NSPredicate predicateWithFormat:@"pnl != nil AND pnl < 0"]];
    } else if ([self.currentFilter isEqualToString:@"open"]) {
        self.entries = [[TAJournalStorage sharedInstance] fetchOpenTrades];
    } else {
        self.entries = allEntries;
    }

    // Update stats
    NSDictionary *stats = [[TAJournalStorage sharedInstance] calculateStatistics];
    NSNumber *totalTrades = stats[@"totalTrades"] ?: @0;
    NSNumber *closedTrades = stats[@"closedTrades"] ?: @0;
    NSNumber *openTrades = stats[@"openTrades"] ?: @0;
    NSNumber *winRate = stats[@"winRate"] ?: @0;
    NSNumber *totalPnL = stats[@"totalPnL"] ?: @0;

    self.statsLabel.text = [NSString stringWithFormat:
        @"Total: %@  |  Closed: %@  |  Open: %@\n"
        @"Win Rate: %.1f%%  |  Total PnL: $%.2f",
        totalTrades, closedTrades, openTrades,
        winRate.doubleValue, totalPnL.doubleValue];

    [self.tableView reloadData];
}

- (void)filterChanged {
    NSInteger index = self.filterControl.selectedSegmentIndex;
    switch (index) {
        case 0: self.currentFilter = @"all"; break;
        case 1: self.currentFilter = @"wins"; break;
        case 2: self.currentFilter = @"losses"; break;
        case 3: self.currentFilter = @"open"; break;
        default: self.currentFilter = @"all"; break;
    }
    [self refreshData];
}

- (void)exportTapped {
    NSURL *fileURL = [[TAJournalStorage sharedInstance] exportToCSVFile];
    if (!fileURL) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Export Failed"
                                                                       message:@"Could not create CSV file"
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Show success alert with file path
    NSString *message = [NSString stringWithFormat:@"CSV exported to:\n%@", fileURL.path];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Export Complete"
                                                                   message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"JournalCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    cell.textLabel.numberOfLines = 0;
    cell.textLabel.font = [UIFont systemFontOfSize:12];

    TATradeJournal *entry = self.entries[indexPath.row];

    // Format timestamp
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateFormat = @"MM/dd HH:mm";
    NSString *dateStr = entry.timestamp ? [formatter stringFromDate:entry.timestamp] : @"--";

    // Build display text
    NSMutableString *text = [NSMutableString string];
    [text appendFormat:@"%@ | %@", dateStr, entry.symbol ?: @"--"];

    if (entry.aiAction.length > 0) {
        [text appendFormat:@" | AI: %@", entry.aiAction];
        if (entry.aiConfidence) {
            [text appendFormat:@" (%.0f%%)", entry.aiConfidence.doubleValue];
        }
    }

    if (entry.side.length > 0 && entry.size) {
        [text appendFormat:@"\n%@ %@ @ $%@",
            [entry.side uppercaseString],
            entry.size.stringValue ?: @"--",
            entry.entryPrice.stringValue ?: @"--"];
    }

    if (entry.pnl) {
        NSString *pnlStr = [NSString stringWithFormat:@"$%.2f (%.1f%%)",
            entry.pnl.doubleValue, entry.pnlPercent.doubleValue];
        [text appendFormat:@"\nPnL: %@", pnlStr];
    }

    if (entry.orderStatus.length > 0) {
        [text appendFormat:@" | %@", entry.orderStatus];
    }

    cell.textLabel.text = text;

    // Color based on PnL
    if (entry.pnl) {
        if ([entry.pnl compare:[NSDecimalNumber zero]] == NSOrderedDescending) {
            cell.textLabel.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.5 alpha:1.0];
        } else if ([entry.pnl compare:[NSDecimalNumber zero]] == NSOrderedAscending) {
            cell.textLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
        } else {
            cell.textLabel.textColor = [UIColor lightGrayColor];
        }
    } else {
        cell.textLabel.textColor = [UIColor lightGrayColor];
    }

    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    TATradeJournal *entry = self.entries[indexPath.row];

    // Show detail alert
    NSMutableString *detail = [NSMutableString string];
    [detail appendFormat:@"Symbol: %@\n", entry.symbol ?: @"--"];
    [detail appendFormat:@"AI Model: %@\n", entry.aiModel ?: @"--"];
    [detail appendFormat:@"Strategy: %@\n", entry.aiStrategy ?: @"--"];
    [detail appendFormat:@"AI Decision: %@\n", entry.aiAction ?: @"--"];
    [detail appendFormat:@"Confidence: %@%%\n", entry.aiConfidence ?: @"--"];

    if (entry.aiRationale.length > 0) {
        NSString *rationale = entry.aiRationale;
        if (rationale.length > 200) {
            rationale = [[rationale substringToIndex:200] stringByAppendingString:@"..."];
        }
        [detail appendFormat:@"\nRationale: %@\n", rationale];
    }

    if (entry.orderId) {
        [detail appendFormat:@"\nOrder ID: %@\n", entry.orderId];
        [detail appendFormat:@"Side: %@\n", entry.side ?: @"--"];
        [detail appendFormat:@"Size: %@\n", entry.size.stringValue ?: @"--"];
        [detail appendFormat:@"Entry: $%@\n", entry.entryPrice.stringValue ?: @"--"];
        [detail appendFormat:@"Status: %@\n", entry.orderStatus ?: @"--"];
    }

    if (entry.pnl) {
        [detail appendFormat:@"\nPnL: $%.2f (%.1f%%)\n", entry.pnl.doubleValue, entry.pnlPercent.doubleValue];
        [detail appendFormat:@"Exit Reason: %@\n", entry.exitReason ?: @"--"];
    }

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Trade Details"
                                                                   message:detail
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];

    // Add delete action
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
        [[TAJournalStorage sharedInstance] deleteEntry:entry.entryId];
        [self refreshData];
    }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        TATradeJournal *entry = self.entries[indexPath.row];
        [[TAJournalStorage sharedInstance] deleteEntry:entry.entryId];
        [self refreshData];
    }
}

@end
