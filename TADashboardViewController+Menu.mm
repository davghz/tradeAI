/**
 * TADashboardViewController+Menu.mm
 */

#import "TADashboardViewController+Private.h"
#import "TASettingsViewController.h"
#import "TAPortfolioViewController.h"
#import "TAWatchlistViewController.h"
#import "TAJournalViewController.h"

static CGFloat sideMenuWidthForBounds(CGRect bounds) {
    return MIN(300.0, bounds.size.width * 0.78);
}

@implementation TADashboardViewController (Menu)

- (void)setupSideMenu {
    if (self.sideMenuOverlay) {
        return;
    }

    self.sideMenuOverlay = [[UIView alloc] initWithFrame:self.view.bounds];
    self.sideMenuOverlay.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.45];
    self.sideMenuOverlay.alpha = 0.0;
    self.sideMenuOverlay.hidden = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideSideMenu)];
    tap.delegate = self;
    [self.sideMenuOverlay addGestureRecognizer:tap];

    [self.view addSubview:self.sideMenuOverlay];

    self.sideMenuContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.sideMenuContainer.backgroundColor = [UIColor colorWithRed:0.06 green:0.07 blue:0.10 alpha:0.98];
    self.sideMenuContainer.layer.shadowColor = [UIColor blackColor].CGColor;
    self.sideMenuContainer.layer.shadowOpacity = 0.35;
    self.sideMenuContainer.layer.shadowRadius = 14.0;
    self.sideMenuContainer.layer.shadowOffset = CGSizeMake(3, 0);
    [self.sideMenuOverlay addSubview:self.sideMenuContainer];

    self.sideMenuHeaderLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    self.sideMenuHeaderLabel.text = @"TradeAI";
    self.sideMenuHeaderLabel.textColor = [UIColor whiteColor];
    self.sideMenuHeaderLabel.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:20] ?: [UIFont boldSystemFontOfSize:20];
    [self.sideMenuContainer addSubview:self.sideMenuHeaderLabel];

    self.sideMenuStack = [[UIStackView alloc] initWithFrame:CGRectZero];
    self.sideMenuStack.axis = UILayoutConstraintAxisVertical;
    self.sideMenuStack.spacing = 12.0;
    [self.sideMenuContainer addSubview:self.sideMenuStack];

    [self.sideMenuStack addArrangedSubview:[self menuButtonWithTitle:@"Trade Dashboard" tag:0]];
    [self.sideMenuStack addArrangedSubview:[self menuButtonWithTitle:@"Portfolio" tag:1]];
    [self.sideMenuStack addArrangedSubview:[self menuButtonWithTitle:@"Watchlist" tag:2]];
    [self.sideMenuStack addArrangedSubview:[self menuButtonWithTitle:@"Trade Journal" tag:3]];
    [self.sideMenuStack addArrangedSubview:[self menuButtonWithTitle:@"Settings" tag:4]];

    [self layoutSideMenu];
}

- (UIButton *)menuButtonWithTitle:(NSString *)title tag:(NSInteger)tag {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    [button setTitle:title forState:UIControlStateNormal];
    [button setTitleColor:[UIColor colorWithWhite:0.9 alpha:1.0] forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
    button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
    button.contentEdgeInsets = UIEdgeInsetsMake(10, 14, 10, 14);
    button.layer.cornerRadius = 12.0;
    button.backgroundColor = [UIColor colorWithWhite:0.12 alpha:1.0];
    button.tag = tag;
    [button addTarget:self action:@selector(menuButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
    return button;
}

- (void)layoutSideMenu {
    if (!self.sideMenuOverlay) {
        return;
    }

    CGRect bounds = self.view.bounds;
    self.sideMenuOverlay.frame = bounds;

    CGFloat menuWidth = sideMenuWidthForBounds(bounds);
    CGFloat height = bounds.size.height;
    CGFloat x = self.sideMenuVisible ? 0.0 : -menuWidth;
    self.sideMenuContainer.frame = CGRectMake(x, 0, menuWidth, height);

    CGFloat topInset = self.view.safeAreaInsets.top;
    self.sideMenuHeaderLabel.frame = CGRectMake(18, MAX(16, topInset + 10), menuWidth - 36, 24);
    CGFloat stackY = CGRectGetMaxY(self.sideMenuHeaderLabel.frame) + 16;
    self.sideMenuStack.frame = CGRectMake(16, stackY, menuWidth - 32, height - stackY - 24);
}

- (void)toggleSideMenu {
    if (self.sideMenuVisible) {
        [self hideSideMenu];
    } else {
        [self showSideMenu];
    }
}

- (void)showSideMenu {
    if (self.sideMenuVisible) {
        return;
    }
    self.sideMenuVisible = YES;

    CGRect bounds = self.view.bounds;
    CGFloat menuWidth = sideMenuWidthForBounds(bounds);
    CGFloat height = bounds.size.height;

    self.sideMenuOverlay.hidden = NO;
    self.sideMenuOverlay.alpha = 0.0;
    self.sideMenuContainer.frame = CGRectMake(-menuWidth, 0, menuWidth, height);

    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         self.sideMenuOverlay.alpha = 1.0;
                         self.sideMenuContainer.frame = CGRectMake(0, 0, menuWidth, height);
                     }
                     completion:nil];
}

- (void)hideSideMenu {
    if (!self.sideMenuVisible) {
        return;
    }

    CGRect bounds = self.view.bounds;
    CGFloat menuWidth = sideMenuWidthForBounds(bounds);
    CGFloat height = bounds.size.height;

    [UIView animateWithDuration:0.22
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
                         self.sideMenuOverlay.alpha = 0.0;
                         self.sideMenuContainer.frame = CGRectMake(-menuWidth, 0, menuWidth, height);
                     }
                     completion:^(BOOL finished) {
                         self.sideMenuOverlay.hidden = YES;
                         self.sideMenuVisible = NO;
                     }];
}

- (void)menuButtonTapped:(UIButton *)sender {
    NSInteger tag = sender.tag;
    [self hideSideMenu];

    if (tag == 0) {
        [self selectTabForRootClass:[TADashboardViewController class]];
        return;
    }
    if (tag == 1) {
        [self selectTabForRootClass:[TAPortfolioViewController class]];
        return;
    }
    if (tag == 2) {
        [self selectTabForRootClass:[TAWatchlistViewController class]];
        return;
    }
    if (tag == 4) {
        [self openSettings];
        return;
    }

    if (tag == 3) {
        TAJournalViewController *journal = [[TAJournalViewController alloc] init];
        [self.navigationController pushViewController:journal animated:YES];
    }
}

- (void)selectTabForRootClass:(Class)rootClass {
    if (!self.tabBarController) {
        return;
    }
    NSArray *controllers = self.tabBarController.viewControllers;
    for (NSInteger i = 0; i < controllers.count; i++) {
        UIViewController *vc = controllers[i];
        UIViewController *root = vc;
        if ([vc isKindOfClass:[UINavigationController class]]) {
            root = ((UINavigationController *)vc).viewControllers.firstObject;
        }
        if ([root isKindOfClass:rootClass]) {
            self.tabBarController.selectedIndex = i;
            break;
        }
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if ([touch.view isDescendantOfView:self.sideMenuContainer]) {
        return NO;
    }
    return YES;
}

@end
