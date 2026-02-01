/**
 * TASettingsViewController+UI.mm
 */

#import "TASettingsViewController+Private.h"

@implementation TASettingsViewController (UI)

- (void)setupUI {
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scrollView.alwaysBounceVertical = YES;
    scrollView.contentInset = UIEdgeInsetsMake(0, 0, 220, 0);
    [self.view addSubview:scrollView];
    self.scrollView = scrollView;

    CGFloat y = 20;
    CGFloat margin = 20;
    CGFloat width = self.view.bounds.size.width - (margin * 2);

    // Title
    UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 30)];
    titleLabel.text = @"Coinbase Advanced Trade API v3";
    titleLabel.textColor = [UIColor whiteColor];
    titleLabel.font = [UIFont boldSystemFontOfSize:18];
    [scrollView addSubview:titleLabel];
    y += 40;

    // ECDSA Notice
    UILabel *ecdsaLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 50)];
    ecdsaLabel.text = @"🔐 ECDSA Authentication Enabled";
    ecdsaLabel.textColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.6 alpha:1.0];
    ecdsaLabel.font = [UIFont boldSystemFontOfSize:16];
    ecdsaLabel.numberOfLines = 0;
    [scrollView addSubview:ecdsaLabel];
    y += 60;

    // API Key Section
    UILabel *keyLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 20)];
    keyLabel.text = @"API Key Name (organizations/.../apiKeys/...):";
    keyLabel.textColor = [UIColor lightGrayColor];
    keyLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:keyLabel];
    y += 25;

    self.apiKeyField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 44)];
    self.apiKeyField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.apiKeyField.textColor = [UIColor whiteColor];
    self.apiKeyField.placeholder = @"organizations/xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx/apiKeys/yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy";
    self.apiKeyField.font = [UIFont systemFontOfSize:13];
    self.apiKeyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.apiKeyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.apiKeyField.delegate = self;
    self.apiKeyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 44)];
    self.apiKeyField.leftViewMode = UITextFieldViewModeAlways;
    [scrollView addSubview:self.apiKeyField];
    y += 60;

    // Private Key Section
    UILabel *privateLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 20)];
    privateLabel.text = @"ECDSA Private Key (PEM or base64):";
    privateLabel.textColor = [UIColor lightGrayColor];
    privateLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:privateLabel];
    y += 25;

    self.privateKeyField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 100)];
    self.privateKeyField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.privateKeyField.textColor = [UIColor whiteColor];
    self.privateKeyField.placeholder = @"-----BEGIN EC PRIVATE KEY----- … -----END EC PRIVATE KEY-----";
    self.privateKeyField.font = [UIFont systemFontOfSize:11];
    self.privateKeyField.secureTextEntry = YES;
    self.privateKeyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.privateKeyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.privateKeyField.delegate = self;
    self.privateKeyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 100)];
    self.privateKeyField.leftViewMode = UITextFieldViewModeAlways;
    self.privateKeyField.contentVerticalAlignment = UIControlContentVerticalAlignmentTop;
    [scrollView addSubview:self.privateKeyField];
    y += 120;

    // Test Connection Button
    UIButton *testButton = [UIButton buttonWithType:UIButtonTypeSystem];
    testButton.frame = CGRectMake(margin, y, width, 44);
    testButton.backgroundColor = [UIColor colorWithRed:0.0 green:0.5 blue:1.0 alpha:1.0];
    [testButton setTitle:@"🧪 Test API Connection" forState:UIControlStateNormal];
    [testButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    testButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    testButton.layer.cornerRadius = 8;
    [testButton addTarget:self action:@selector(testConnection) forControlEvents:UIControlEventTouchUpInside];
    [scrollView addSubview:testButton];
    y += 70;

    // Ed25519 Section Divider
    UIView *divider = [[UIView alloc] initWithFrame:CGRectMake(margin, y, width, 1)];
    divider.backgroundColor = [UIColor colorWithWhite:0.3 alpha:1.0];
    [scrollView addSubview:divider];
    y += 20;

    // Ed25519 Title
    UILabel *ed25519Title = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 30)];
    ed25519Title.text = @"Ed25519 Authentication (Alternative)";
    ed25519Title.textColor = [UIColor whiteColor];
    ed25519Title.font = [UIFont boldSystemFontOfSize:16];
    [scrollView addSubview:ed25519Title];
    y += 35;

    // Ed25519 Notice
    UILabel *ed25519Notice = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 40)];
    ed25519Notice.text = @"🔑 Used as fallback if ECDSA fails";
    ed25519Notice.textColor = [UIColor colorWithRed:0.6 green:0.8 blue:1.0 alpha:1.0];
    ed25519Notice.font = [UIFont systemFontOfSize:13];
    ed25519Notice.numberOfLines = 0;
    [scrollView addSubview:ed25519Notice];
    y += 45;

    // Ed25519 API Key Section
    UILabel *ed25519KeyLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 20)];
    ed25519KeyLabel.text = @"Ed25519 API Key ID:";
    ed25519KeyLabel.textColor = [UIColor lightGrayColor];
    ed25519KeyLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:ed25519KeyLabel];
    y += 25;

    self.ed25519ApiKeyField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 44)];
    self.ed25519ApiKeyField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.ed25519ApiKeyField.textColor = [UIColor whiteColor];
    self.ed25519ApiKeyField.placeholder = @"xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx";
    self.ed25519ApiKeyField.font = [UIFont systemFontOfSize:13];
    self.ed25519ApiKeyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.ed25519ApiKeyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.ed25519ApiKeyField.delegate = self;
    self.ed25519ApiKeyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 44)];
    self.ed25519ApiKeyField.leftViewMode = UITextFieldViewModeAlways;
    [scrollView addSubview:self.ed25519ApiKeyField];
    y += 55;

    // Ed25519 Private Key Section
    UILabel *ed25519PrivateLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 20)];
    ed25519PrivateLabel.text = @"Ed25519 Private Key (base64):";
    ed25519PrivateLabel.textColor = [UIColor lightGrayColor];
    ed25519PrivateLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:ed25519PrivateLabel];
    y += 25;

    self.ed25519PrivateKeyField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 60)];
    self.ed25519PrivateKeyField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.ed25519PrivateKeyField.textColor = [UIColor whiteColor];
    self.ed25519PrivateKeyField.placeholder = @"base64 encoded 64-byte key...";
    self.ed25519PrivateKeyField.font = [UIFont systemFontOfSize:11];
    self.ed25519PrivateKeyField.secureTextEntry = YES;
    self.ed25519PrivateKeyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.ed25519PrivateKeyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.ed25519PrivateKeyField.delegate = self;
    self.ed25519PrivateKeyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 60)];
    self.ed25519PrivateKeyField.leftViewMode = UITextFieldViewModeAlways;
    [scrollView addSubview:self.ed25519PrivateKeyField];
    y += 80;

    // Instructions
    UITextView *instructions = [[UITextView alloc] initWithFrame:CGRectMake(margin, y, width, 280)];
    instructions.backgroundColor = [UIColor clearColor];
    instructions.textColor = [UIColor lightGrayColor];
    instructions.font = [UIFont systemFontOfSize:12];
    instructions.editable = NO;
    instructions.scrollEnabled = NO;
    instructions.userInteractionEnabled = NO;
    instructions.text = @"How to get API Keys:\n\n"
        @"1. Go to https://portal.cdp.coinbase.com/\n"
        @"2. Create a new project\n"
        @"3. Go to API Keys section\n"
        @"4. Create new API key with 'Trade' permission\n"
        @"5. Select signing algorithm:\n"
        @"   • ECDSA (ES256) - uses organizations/.../apiKeys/... format\n"
        @"   • Ed25519 (EdDSA) - uses UUID format key ID\n"
        @"6. Download the private key file\n"
        @"7. Copy the API Key ID and Private Key\n\n"
        @"Note: Ed25519 is used as fallback if ECDSA fails.\n"
        @"Keep your private keys secure!";
    [scrollView addSubview:instructions];
    y += 300;

    // OpenRouter Settings
    UILabel *aiTitle = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 22)];
    aiTitle.text = @"AI Trading (OpenRouter)";
    aiTitle.textColor = [UIColor whiteColor];
    aiTitle.font = [UIFont boldSystemFontOfSize:16];
    [scrollView addSubview:aiTitle];
    y += 30;

    UILabel *openRouterKeyLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 18)];
    openRouterKeyLabel.text = @"OpenRouter API Key";
    openRouterKeyLabel.textColor = [UIColor lightGrayColor];
    openRouterKeyLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:openRouterKeyLabel];
    y += 22;

    self.openRouterKeyField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 44)];
    self.openRouterKeyField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.openRouterKeyField.textColor = [UIColor whiteColor];
    self.openRouterKeyField.placeholder = @"sk-or-...";
    self.openRouterKeyField.font = [UIFont systemFontOfSize:13];
    self.openRouterKeyField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.openRouterKeyField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.openRouterKeyField.delegate = self;
    self.openRouterKeyField.secureTextEntry = YES;
    self.openRouterKeyField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 44)];
    self.openRouterKeyField.leftViewMode = UITextFieldViewModeAlways;
    [scrollView addSubview:self.openRouterKeyField];
    y += 60;

    UILabel *modelLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 18)];
    modelLabel.text = @"Model (OpenRouter ID)";
    modelLabel.textColor = [UIColor lightGrayColor];
    modelLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:modelLabel];
    y += 22;

    self.modelField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 44)];
    self.modelField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.modelField.textColor = [UIColor whiteColor];
    self.modelField.placeholder = @"openai/gpt-4o-mini";
    self.modelField.font = [UIFont systemFontOfSize:13];
    self.modelField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.modelField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.modelField.delegate = self;
    self.modelField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 44)];
    self.modelField.leftViewMode = UITextFieldViewModeAlways;
    [scrollView addSubview:self.modelField];
    y += 60;

    UILabel *strategyLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 18)];
    strategyLabel.text = @"AI Strategy Preset";
    strategyLabel.textColor = [UIColor lightGrayColor];
    strategyLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:strategyLabel];
    y += 22;

    self.strategyControl = [[UISegmentedControl alloc] initWithItems:@[@"Conservative", @"Balanced", @"Aggressive", @"Custom"]];
    self.strategyControl.selectedSegmentIndex = 1;
    self.strategyControl.tintColor = [UIColor colorWithRed:0.2 green:0.9 blue:0.7 alpha:1.0];
    [self.strategyControl addTarget:self action:@selector(strategyChanged) forControlEvents:UIControlEventValueChanged];
    self.strategyControl.frame = CGRectMake(margin, y, width, 34);
    [scrollView addSubview:self.strategyControl];
    y += 48;

    UILabel *customPromptLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 18)];
    customPromptLabel.text = @"Custom Prompt (optional)";
    customPromptLabel.textColor = [UIColor lightGrayColor];
    customPromptLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:customPromptLabel];
    y += 22;

    self.customPromptField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 44)];
    self.customPromptField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.customPromptField.textColor = [UIColor whiteColor];
    self.customPromptField.placeholder = @"Describe your custom trading behavior...";
    self.customPromptField.font = [UIFont systemFontOfSize:12];
    self.customPromptField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.customPromptField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.customPromptField.delegate = self;
    self.customPromptField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 44)];
    self.customPromptField.leftViewMode = UITextFieldViewModeAlways;
    [scrollView addSubview:self.customPromptField];
    y += 60;

    UILabel *autoTradeLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width - 80, 20)];
    autoTradeLabel.text = @"Enable Auto-Trading";
    autoTradeLabel.textColor = [UIColor lightGrayColor];
    autoTradeLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:autoTradeLabel];

    self.autoTradeSwitch = [[UISwitch alloc] initWithFrame:CGRectZero];
    self.autoTradeSwitch.onTintColor = [UIColor colorWithRed:0.0 green:0.7 blue:0.3 alpha:1.0];
    CGRect switchFrame = self.autoTradeSwitch.frame;
    self.autoTradeSwitch.frame = CGRectMake(margin + width - switchFrame.size.width,
                                            y - 6,
                                            switchFrame.size.width,
                                            switchFrame.size.height);
    [scrollView addSubview:self.autoTradeSwitch];
    y += 40;

    UILabel *sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(margin, y, width, 18)];
    sizeLabel.text = @"Trade Size (quote for BUY / base for SELL)";
    sizeLabel.textColor = [UIColor lightGrayColor];
    sizeLabel.font = [UIFont systemFontOfSize:12];
    [scrollView addSubview:sizeLabel];
    y += 22;

    self.tradeSizeField = [[UITextField alloc] initWithFrame:CGRectMake(margin, y, width, 44)];
    self.tradeSizeField.backgroundColor = [UIColor colorWithWhite:0.15 alpha:1.0];
    self.tradeSizeField.textColor = [UIColor whiteColor];
    self.tradeSizeField.placeholder = @"10";
    self.tradeSizeField.font = [UIFont systemFontOfSize:13];
    self.tradeSizeField.autocorrectionType = UITextAutocorrectionTypeNo;
    self.tradeSizeField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.tradeSizeField.keyboardType = UIKeyboardTypeDecimalPad;
    self.tradeSizeField.delegate = self;
    self.tradeSizeField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 44)];
    self.tradeSizeField.leftViewMode = UITextFieldViewModeAlways;
    [scrollView addSubview:self.tradeSizeField];
    y += 60;

    self.contentHeight = y + 60;
}

@end

