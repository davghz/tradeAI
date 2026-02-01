/**
 * TASettingsViewController+Private.h
 */

#import "TASettingsViewController.h"

NS_ASSUME_NONNULL_BEGIN

@interface TASettingsViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *apiKeyField;
@property (nonatomic, strong) UITextField *privateKeyField;
@property (nonatomic, strong) UITextField *ed25519ApiKeyField;
@property (nonatomic, strong) UITextField *ed25519PrivateKeyField;
@property (nonatomic, strong) UITextField *openRouterKeyField;
@property (nonatomic, strong) UITextField *modelField;
@property (nonatomic, strong) UISegmentedControl *strategyControl;
@property (nonatomic, strong) UITextField *customPromptField;
@property (nonatomic, strong) UISwitch *autoTradeSwitch;
@property (nonatomic, strong) UITextField *tradeSizeField;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, assign) CGFloat contentHeight;
@property (nonatomic, weak) UITextField *activeField;

- (void)setupUI;
- (void)loadSettings;
- (void)saveSettings;
- (void)strategyChanged;
- (BOOL)isValidAPIKeyName:(NSString *)apiKeyName;
- (BOOL)isValidUUIDFormat:(NSString *)uuid;
- (void)testConnection;
- (void)showAlert:(NSString *)title message:(NSString *)message;
- (void)keyboardWillShow:(NSNotification *)notification;
- (void)keyboardWillHide:(NSNotification *)notification;

@end

NS_ASSUME_NONNULL_END
