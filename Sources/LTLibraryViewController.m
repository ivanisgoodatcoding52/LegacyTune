#import "LTLibraryViewController.h"

@implementation LTLibraryViewController

- (id)init {
	self = [super init];
	if (self) {
		self.title = @"Library";
	}
	return self;
}

- (void)loadView {
	self.view = [[[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]] autorelease];
	self.view.backgroundColor = [UIColor blackColor];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	UILabel *placeholder = [[UILabel alloc] initWithFrame:CGRectMake(16, 16, self.view.bounds.size.width - 32, self.view.bounds.size.height - 32)];
	placeholder.text = @"TODO: browse by Artists, Albums, Songs, Genres, Compilations, Years, Folders.";
	placeholder.textColor = [UIColor lightGrayColor];
	placeholder.backgroundColor = [UIColor clearColor];
	placeholder.font = [UIFont systemFontOfSize:14];
	placeholder.numberOfLines = 0;
	[self.view addSubview:placeholder];
	[placeholder release];
}

@end
