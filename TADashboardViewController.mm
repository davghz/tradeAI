/**
 * TADashboardViewController.mm
 * Trading Dashboard with ECDSA Authentication
 * Coinbase Advanced Trade API v3
 */

#import "TADashboardViewController+Private.h"
#import "TAAppDebugLog.h"

@implementation TADashboardViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    TASetDebugStage(@"dashboard_viewDidLoad_start");
    self.title = @"TradeAI";
    self.view.backgroundColor = [UIColor blackColor];

    UIBarButtonItem *menuItem = [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"line.3.horizontal"]
                                                                 style:UIBarButtonItemStylePlain
                                                                target:self
                                                                action:@selector(toggleSideMenu)];
    self.navigationItem.leftBarButtonItem = menuItem;

    self.symbols = @[@"BTC-USD", @"ETH-USD", @"SOL-USD", @"ADA-USD", @"DOT-USD",
                     @"LINK-USD", @"UNI-USD", @"AAVE-USD", @"MATIC-USD", @"ATOM-USD"];
    self.selectedSymbol = @"BTC-USD";

    [self setupUI];
    TASetDebugStage(@"dashboard_setupUI_done");
    [self loadAPISettings];
    TASetDebugStage(@"dashboard_loadAPISettings_done");
    [self refreshData];
    TASetDebugStage(@"dashboard_refreshData_done");

    // Auto-refresh every 8 seconds
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:8.0
                                                          target:self
                                                        selector:@selector(refreshData)
                                                        userInfo:nil
                                                         repeats:YES];
    TASetDebugStage(@"dashboard_viewDidLoad_done");
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    TASetDebugStage(@"dashboard_viewWillDisappear");
    [self.refreshTimer invalidate];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    TASetDebugStage(@"dashboard_viewWillAppear");
    [self loadAPISettings];
    [self updateRiskLabels];
    [self updateStrategyLabel];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    TASetDebugStage(@"dashboard_viewDidAppear");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TASetDebugStage(@"dashboard_alive_1s");
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        TASetDebugStage(@"dashboard_alive_3s");
    });
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    TASetDebugStage(@"dashboard_viewDidDisappear");
}

@end
