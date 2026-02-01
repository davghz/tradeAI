/**
 * TASettingsViewController+Keyboard.mm
 */

#import "TASettingsViewController+Private.h"

@implementation TASettingsViewController (Keyboard)

- (void)textFieldDidEndEditing:(UITextField *)textField {
    // Auto-save when core credentials are present
    if (self.apiKeyField.text.length > 0 && self.privateKeyField.text.length > 0) {
        [self saveSettings];
    }
    if (self.activeField == textField) {
        self.activeField = nil;
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    self.activeField = textField;
    return YES;
}

- (void)keyboardWillShow:(NSNotification *)notification {
    CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    CGFloat bottomInset = keyboardFrame.size.height + 20.0;
    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.bottom = bottomInset;
    self.scrollView.contentInset = insets;
    self.scrollView.scrollIndicatorInsets = insets;

    if (self.activeField) {
        CGRect fieldRect = [self.activeField convertRect:self.activeField.bounds toView:self.scrollView];
        [self.scrollView scrollRectToVisible:CGRectInset(fieldRect, 0, -20) animated:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification {
    UIEdgeInsets insets = self.scrollView.contentInset;
    insets.bottom = 220.0;
    self.scrollView.contentInset = insets;
    self.scrollView.scrollIndicatorInsets = insets;
}

@end

