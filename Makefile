TARGET := iphone:clang:13.2.3:13.2
ARCHS := arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TradeAI

TradeAI_FILES = TAAppDebugLog.m TACoinbaseAPI.mm TACoinbaseAPI+Auth.mm TACoinbaseAPI+JWT.mm TACoinbaseAPI+KeyParsing.mm TACoinbaseAPI+Debug.mm TACoinbaseAPI+Market.mm TACoinbaseAPI+Accounts.mm TACoinbaseAPI+Orders.mm TAPortfolio.mm TAChartView.mm TAOpenRouterClient.mm TADashboardViewController.mm TADashboardViewController+Layout.mm TADashboardViewController+UI.mm TADashboardViewController+Data.mm TADashboardViewController+Trading.mm TADashboardViewController+Menu.mm TAAppDelegate.mm TASettingsViewController.mm TASettingsViewController+Layout.mm TASettingsViewController+UI.mm TASettingsViewController+Persistence.mm TASettingsViewController+Keyboard.mm TAPortfolioViewController.mm TAWatchlistViewController.mm TAPortfolioDonutView.mm TAGlassCardView.mm TATradeJournal.mm TAJournalStorage.mm TAJournalViewController.mm main.m sodium/tweetnacl.c sodium/ed25519_tweetnacl.c sodium/randombytes.c
TradeAI_CFLAGS = -fobjc-arc -Wno-error -Isodium
TradeAI_FRAMEWORKS = Foundation UIKit CoreGraphics Security
TradeAI_LDFLAGS = -lSystem -framework Security
TradeAI_ENTITLEMENTS = TradeAI.entitlements

include $(THEOS_MAKE_PATH)/application.mk
