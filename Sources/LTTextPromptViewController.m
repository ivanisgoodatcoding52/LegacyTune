#import "LTTextPromptViewController.h"

@implementation LTTextPromptViewController

@synthesize initialValue = _initialValue;

- (id)initWithTitle:(NSString *)title placeholder:(NSString *)placeholder target:(id)target action:(SEL)action {
	self = [super init];
	if (self) {
		self.title = title;
		_placeholder = [placeholder copy];
		_target = target;
		_action = action;
	}
	return self;
}

- (void)loadView {
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
	self.view.backgroundColor = [UIColor blackColor];

	_textField = [[UITextField alloc] initWithFrame:CGRectMake(16, 16, frame.size.width - 32, 32)];
	_textField.borderStyle = UITextBorderStyleRoundedRect;
	_textField.placeholder = _placeholder;
	_textField.text = _initialValue;
	_textField.delegate = self;
	_textField.returnKeyType = UIReturnKeyDone;
	_textField.autocorrectionType = UITextAutocorrectionTypeNo;
	_textField.clearButtonMode = UITextFieldViewModeWhileEditing;
	[self.view addSubview:_textField];

	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save)] autorelease];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[_textField becomeFirstResponder];
}

- (void)save {
	if (_target != nil && [_target respondsToSelector:_action]) {
		[_target performSelector:_action withObject:_textField.text];
	}
	[self.navigationController popViewControllerAnimated:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[self save];
	return YES;
}

- (void)dealloc {
	[_textField release];
	[_placeholder release];
	[_initialValue release];
	[super dealloc];
}

@end
