#import "LTAddFavoriteViewController.h"
#import "LTDatabase.h"
#import "LTHomeStore.h"

typedef enum {
	LTAddFavoriteTypeArtist = 0,
	LTAddFavoriteTypeAlbum
} LTAddFavoriteType;

@interface LTAddFavoriteViewController (Private)
- (void)typeChanged;
- (void)reloadValues;
@end

@implementation LTAddFavoriteViewController

- (id)init {
	self = [super init];
	if (self) self.title = @"Add Favorite";
	return self;
}

- (void)loadView {
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
	self.view.backgroundColor = [UIColor blackColor];

	NSArray *segmentTitles = [NSArray arrayWithObjects:@"Artists", @"Albums", nil];
	_typeControl = [[UISegmentedControl alloc] initWithItems:segmentTitles];
	_typeControl.frame = CGRectMake(10, 8, frame.size.width - 20, 30);
	_typeControl.selectedSegmentIndex = LTAddFavoriteTypeArtist;
	_typeControl.segmentedControlStyle = UISegmentedControlStyleBar;
	_typeControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[_typeControl addTarget:self action:@selector(typeChanged) forControlEvents:UIControlEventValueChanged];
	[self.view addSubview:_typeControl];

	CGFloat tableY = CGRectGetMaxY(_typeControl.frame) + 8;
	_tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, tableY, frame.size.width, frame.size.height - tableY) style:UITableViewStylePlain];
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.backgroundColor = [UIColor blackColor];
	_tableView.separatorColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[self reloadValues];
}

- (void)typeChanged {
	[self reloadValues];
}

- (void)reloadValues {
	NSString *column = (_typeControl.selectedSegmentIndex == LTAddFavoriteTypeArtist) ? @"artist" : @"album";
	NSString *sql = [NSString stringWithFormat:@"SELECT DISTINCT %@ FROM songs WHERE %@ != '' ORDER BY %@ COLLATE NOCASE ASC", column, column, column];
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:sql withArguments:nil];

	NSMutableArray *values = [NSMutableArray arrayWithCapacity:[rows count]];
	for (NSDictionary *row in rows) [values addObject:[row objectForKey:column]];
	[_values release];
	_values = [values retain];
	[_tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [_values count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"LTAddFavoriteCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier] autorelease];
		cell.textLabel.textColor = [UIColor whiteColor];
		cell.backgroundColor = [UIColor blackColor];
	}
	cell.textLabel.text = [_values objectAtIndex:indexPath.row];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];

	NSString *itemType = (_typeControl.selectedSegmentIndex == LTAddFavoriteTypeArtist) ? @"artist" : @"album";
	NSString *itemKey = [_values objectAtIndex:indexPath.row];
	[[LTHomeStore sharedStore] addFavoriteWithType:itemType key:itemKey];

	[self.navigationController popViewControllerAnimated:YES];
}

- (void)dealloc {
	[_typeControl release];
	[_tableView release];
	[_values release];
	[super dealloc];
}

@end
