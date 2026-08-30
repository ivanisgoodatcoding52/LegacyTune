#import "LTFavoritesManagerViewController.h"
#import "LTHomeStore.h"
#import "LTHomeModels.h"
#import "LTAddFavoriteViewController.h"

@interface LTFavoritesManagerViewController (Private)
- (void)reload;
- (void)addTapped;
@end

@implementation LTFavoritesManagerViewController

- (id)init {
	self = [super init];
	if (self) self.title = @"Favorites";
	return self;
}

- (void)loadView {
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
	self.view.backgroundColor = [UIColor blackColor];

	_tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStylePlain];
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.backgroundColor = [UIColor blackColor];
	_tableView.separatorColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	// PUSHED screen — leftBarButtonItem deliberately untouched so the
	// automatic Back button stays intact (see LTPlaylistDetailViewController
	// for the bug this exact mistake caused earlier).
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addTapped)] autorelease];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reload];
}

- (void)reload {
	[_favorites release];
	_favorites = [[[LTHomeStore sharedStore] favoritesOrdered] retain];
	[_tableView reloadData];
}

- (void)addTapped {
	LTAddFavoriteViewController *add = [[LTAddFavoriteViewController alloc] init];
	[self.navigationController pushViewController:add animated:YES];
	[add release];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_favorites count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"LTFavoriteCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier] autorelease];
		cell.textLabel.textColor = [UIColor whiteColor];
		cell.detailTextLabel.textColor = [UIColor lightGrayColor];
		cell.backgroundColor = [UIColor blackColor];
	}
	LTHomeFavorite *favorite = [_favorites objectAtIndex:indexPath.row];
	cell.textLabel.text = favorite.title;
	cell.detailTextLabel.text = favorite.subtitle;
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle == UITableViewCellEditingStyleDelete) {
		LTHomeFavorite *favorite = [_favorites objectAtIndex:indexPath.row];
		[[LTHomeStore sharedStore] removeFavorite:favorite];
		[self reload];
	}
}

- (void)dealloc {
	[_tableView release];
	[_favorites release];
	[super dealloc];
}

@end
