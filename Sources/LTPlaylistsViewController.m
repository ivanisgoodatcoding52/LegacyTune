#import "LTPlaylistsViewController.h"

@implementation LTPlaylistsViewController

- (id)init {
	self = [super init];
	if (self) {
		self.title = @"Playlists";
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
	placeholder.text = @"TODO: manual + automatic playlists, playlist folders, import/export.";
	placeholder.textColor = [UIColor lightGrayColor];
	placeholder.backgroundColor = [UIColor clearColor];
	placeholder.font = [UIFont systemFontOfSize:14];
	placeholder.numberOfLines = 0;
	[self.view addSubview:placeholder];
	[placeholder release];
}

@end
