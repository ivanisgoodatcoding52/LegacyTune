#import "LTPlayerViewController.h"

@implementation LTPlayerViewController

- (void)loadView {
	self.view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	self.view.backgroundColor = [UIColor blackColor];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	UILabel *placeholder = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, self.view.bounds.size.width - 32, self.view.bounds.size.height - 32)];
	placeholder.text = @"TODO: artwork, transport controls, queue, gapless/crossfade playback via AVAudioPlayer or Audio Queue Services, scrubber, sleep timer, playback speed.";
	placeholder.textColor = [UIColor lightGrayColor];
	placeholder.backgroundColor = [UIColor clearColor];
	placeholder.font = [UIFont systemFontOfSize:14];
	placeholder.numberOfLines = 0;
	[self.view addSubview:placeholder];
	[placeholder release];

	UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	closeButton.frame = CGRectMake(16, 40, 60, 30);
	[closeButton setTitle:@"Close" forState:UIControlStateNormal];
	[closeButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:closeButton];
}

- (void)closeTapped {
	[self dismissModalViewControllerAnimated:YES]; // pre-iOS5 API; -dismissViewControllerAnimated:completion: is iOS5+
}

@end
