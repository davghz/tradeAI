/**
 * TASettingsViewController+Layout.mm
 */

#import "TASettingsViewController+Private.h"

@implementation TASettingsViewController (Layout)

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    CGFloat minHeight = self.view.bounds.size.height + 1.0;
    CGFloat height = MAX(self.contentHeight, minHeight);
    self.scrollView.contentSize = CGSizeMake(self.view.bounds.size.width, height);
}

@end

