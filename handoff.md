# Debugging Handoff: Modular App Crash

## Problem Summary
The app crashes immediately on launch after modularization (builds 56/57). Build 55 (original non-modular) works fine.

## Root Cause Identified
The API signature for `TAOpenRouterClient` was changed but **the header and implementation are now consistent in the modular version**. The crash is likely caused by something else.

## Key Differences Found

### 1. TAOpenRouterClient Signature Change
**Original** (`backup/openclawiostweak/OrchestratedApp/TAOpenRouterClient.h`):
```objc
completion:(void (^)(NSString * _Nullable decision, NSError * _Nullable error))completion;
```

**Modular** (`OrchestratedAppBuild/shared/OrchestratedApp/TAOpenRouterClient.h`):
```objc
completion:(void (^)(NSDictionary * _Nullable response, NSError * _Nullable error))completion;
```
- This change is **consistent** between .h and .mm in modular version - NOT the crash cause.

### 2. New Files Added (32 new files)
- `TAPortfolioViewController.h/mm` - New Portfolio tab
- `TAWatchlistViewController.h/mm` - New Watchlist tab
- `TAJournalViewController.h/mm` - New Journal tab
- `TAGlassCardView.h/mm` - Glassmorphism card component
- `TAPortfolioDonutView.h/mm` - Donut chart for portfolio
- `TATradeJournal.h/mm` - Trade journal model
- `TAJournalStorage.h/mm` - Journal persistence
- Category files for modularization (+Layout, +UI, +Data, +Trading, etc.)

### 3. TAAppDelegate Changes
**Original**: Single navigation controller with TADashboardViewController
**Modular**: Tab bar with 4 tabs (Trade, Portfolio, Watchlist, Settings)

### 4. Category Architecture
TADashboardViewController split into:
- `TADashboardViewController.mm` (51 lines - just viewDidLoad)
- `TADashboardViewController+Private.h` (properties + method declarations)
- `TADashboardViewController+UI.mm` (setupUI, createCard)
- `TADashboardViewController+Layout.mm` (viewDidLayoutSubviews)
- `TADashboardViewController+Data.mm` (loadAPISettings, refreshData)
- `TADashboardViewController+Trading.mm` (trading logic, AI, orders)

Same pattern for TASettingsViewController and TACoinbaseAPI.

## Likely Crash Causes to Investigate

### 1. Missing Method in viewWillAppear
In modular `TADashboardViewController.mm:43-48`:
```objc
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self loadAPISettings];
    [self updateRiskLabels];    // NEW - declared in +Private.h, implemented in +Trading.mm
    [self updateStrategyLabel]; // NEW - declared in +Private.h, implemented in +Trading.mm
}
```
These methods ARE implemented in +Trading.mm, so this should work.

### 2. Category Load Order Issue
Categories must be linked properly. Check Makefile includes all category .mm files:
```makefile
OrchestratedTradingApp_FILES = ... TADashboardViewController+Layout.mm TADashboardViewController+UI.mm TADashboardViewController+Data.mm TADashboardViewController+Trading.mm ...
```

### 3. Possible Nil Dereference
In `TADashboardViewController+UI.mm:264-265`:
```objc
[self updateRiskLabels];
[self updateStrategyLabel];
```
These are called at the end of `setupUI` before the view is fully set up. If these access nil UI elements, crash could occur.

### 4. TAGlassCardView Used Everywhere
The modular version replaces `createCard` to return `TAGlassCardView` instead of plain UIView:
```objc
// Original
- (UIView *)createCard {
    UIView *card = [[UIView alloc] initWithFrame:CGRectZero];
    // ... setup ...
    return card;
}

// Modular
- (UIView *)createCard {
    return [[TAGlassCardView alloc] initWithFrame:CGRectZero];
}
```
If TAGlassCardView.mm has issues or isn't linked, crash on first card creation.

### 5. New View Controllers in Tab Bar
`TAPortfolioViewController`, `TAWatchlistViewController` are instantiated in `TAAppDelegate.mm`. If their headers or implementations have issues, crash on launch.

## Files to Check

| File | What to Check |
|------|---------------|
| `Makefile` | Ensure ALL .mm files are listed in FILES |
| `TAGlassCardView.mm` | Verify it compiles and links |
| `TAPortfolioViewController.mm` | Check for nil dereferences |
| `TAWatchlistViewController.mm` | Check for nil dereferences |
| `TADashboardViewController+Private.h` | Property declarations match usage |

## Quick Debug Steps

1. **Check Makefile** - Verify all source files are listed
2. **Add NSLog** - Add `NSLog(@"AppDelegate starting");` as first line in `application:didFinishLaunchingWithOptions:`
3. **Comment out tabs** - Try with just TADashboardViewController (no tab bar)
4. **Check for import cycles** - Private.h imports may cause issues

## File Locations

- **Modular (broken)**: `/home/davgz/Documents/Cursor/iOSrun/OrchestratedAppBuild/shared/OrchestratedApp/`
- **Original (working)**: `/home/davgz/Documents/Cursor/iOSrun/backup/openclawiostweak/OrchestratedApp/`

## Build Commands
```bash
cd /home/davgz/Documents/Cursor/iOSrun/OrchestratedAppBuild/shared/OrchestratedApp
make clean && make package install
```

## MCP Tools Available
- `mcp__iosrun-mcp__build_and_install` - Build and deploy
- `mcp__iosrun-mcp__respring` - Respring device
- `mcp__iosrun-mcp__screenshot` - Take screenshot for verification

## Recommendation
Start by adding logging to TAAppDelegate to see how far initialization gets before crash. Then systematically comment out new components until the crash stops.
