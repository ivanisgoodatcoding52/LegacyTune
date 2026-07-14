#import <UIKit/UIKit.h>

// A minimal single-field text prompt, pushed onto the nav stack. Exists
// because UIAlertView's UIAlertViewStylePlainTextInput is iOS 5.0+ only,
// and this project's floor is iOS 3.0 — a plain pushed view with a
// UITextField is the compatible way to ask for one line of text (playlist
// names, renames, etc.) across the whole supported range.
@interface LTTextPromptViewController : UIViewController <UITextFieldDelegate> {
	UITextField *_textField;
	NSString *_placeholder;
	NSString *_initialValue;
	id _target;
	SEL _action;
}

// target/action fires with a single NSString argument (the entered text)
// when the user taps Save or hits Return. target is not retained — the
// standard target-action convention assumes the caller (typically the
// view controller that pushed this one) outlives it.
- (id)initWithTitle:(NSString *)title placeholder:(NSString *)placeholder target:(id)target action:(SEL)action;

@property (nonatomic, copy) NSString *initialValue;

@end
