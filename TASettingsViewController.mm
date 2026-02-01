/**
 * TASettingsViewController.mm
 * ECDSA API Key Configuration for Coinbase Advanced Trade API v3
 * https://docs.cdp.coinbase.com/coinbase-app/advanced-trade-apis/rest-api
 */

#import "TASettingsViewController+Private.h"

@implementation TASettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"API Settings";
    self.view.backgroundColor = [UIColor blackColor];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                                             target:self
                                                                                             action:@selector(saveSettings)];

    [self setupUI];
    [self loadSettings];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end

