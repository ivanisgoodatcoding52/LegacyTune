#import <UIKit/UIKit.h>

@interface LTTextPromptViewController : UIViewController <UITextFieldDelegate> {
	UITextField *_textField;
	NSString *_placeholder;
	NSString *_initialValue;
	id _target;
	SEL _action;
}

- (id)initWithTitle:(NSString *)title placeholder:(NSString *)placeholder target:(id)target action:(SEL)action;
@property (nonatomic, copy) NSString *initialValue;

@end
