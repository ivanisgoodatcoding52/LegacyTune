#import "LTSettingsViewController.h"
#import "LTDatabase.h"
#import "LTLibraryScanner.h"

typedef enum {
	LTSettingsSectionLibrary = 0,
	LTSettingsSectionStatistics,
	LTSettingsSectionStorage,
	LTSettingsSectionDangerZone,
	LTSettingsSectionAbout,
	LTSettingsSectionCount
} LTSettingsSection;

static const NSInteger kLTActionSheetTagClearArtwork = 1;
static const NSInteger kLTActionSheetTagResetDatabase = 2;

@interface LTSettingsViewController (Private)
- (void)scannerStatusChanged;
- (void)rescanTapped;
- (void)clearArtworkCacheTapped;
- (void)resetDatabaseTapped;
- (void)performClearArtworkCache;
- (void)performResetDatabase;
- (NSInteger)songCount;
- (NSInteger)playlistCount;
- (NSString *)artworkCacheSizeDescription;
@end

@implementation LTSettingsViewController

- (id)init {
	self = [super init];
	if (self) {
		self.title = @"Settings";
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(scannerStatusChanged) name:LTLibraryScannerDidFinishNotification object:nil];
	}
	return self;
}

- (void)loadView {
	CGRect frame = [[UIScreen mainScreen] applicationFrame];
	self.view = [[[UIView alloc] initWithFrame:frame] autorelease];
	self.view.backgroundColor = [UIColor blackColor];

	_tableView = [[UITableView alloc] initWithFrame:frame style:UITableViewStyleGrouped];
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.backgroundColor = [UIColor blackColor];
	_tableView.separatorColor = [UIColor colorWithWhite:0.25f alpha:1.0f];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:_tableView];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	_isScanning = [[LTLibraryScanner sharedScanner] isScanning];
	[_tableView reloadData];
}

- (void)scannerStatusChanged {
	_isScanning = [[LTLibraryScanner sharedScanner] isScanning];
	[_tableView reloadData];
}

- (void)rescanTapped {
	if ([[LTLibraryScanner sharedScanner] isScanning]) return;
	_isScanning = YES;
	[_tableView reloadData];
	[[LTLibraryScanner sharedScanner] startScan];
}

- (void)clearArtworkCacheTapped {
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Clear all cached artwork? It will be re-cached from your library on the next rescan."
		delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Clear Artwork Cache" otherButtonTitles:nil];
	sheet.tag = kLTActionSheetTagClearArtwork;
	[sheet showInView:self.view];
	[sheet release];
}

- (void)resetDatabaseTapped {
	UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Delete all songs and playlists from the local database? Your actual music is untouched — this just clears LegacyTune's index, which a rescan will rebuild (playlists will NOT come back)."
		delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Reset Database" otherButtonTitles:nil];
	sheet.tag = kLTActionSheetTagResetDatabase;
	[sheet showInView:self.view];
	[sheet release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	if (buttonIndex != actionSheet.destructiveButtonIndex) return;
	if (actionSheet.tag == kLTActionSheetTagClearArtwork) [self performClearArtworkCache];
	else if (actionSheet.tag == kLTActionSheetTagResetDatabase) [self performResetDatabase];
}

- (void)performClearArtworkCache {
	NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *artworkDir = [[cachesPaths objectAtIndex:0] stringByAppendingPathComponent:@"Artwork"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *files = [fileManager contentsOfDirectoryAtPath:artworkDir error:NULL];
	for (NSString *file in files) [fileManager removeItemAtPath:[artworkDir stringByAppendingPathComponent:file] error:NULL];
	[[LTDatabase sharedDatabase] executeUpdate:@"UPDATE songs SET artwork_path = NULL" withArguments:nil];
	[_tableView reloadData];
}

- (void)performResetDatabase {
	LTDatabase *db = [LTDatabase sharedDatabase];
	[db beginTransaction];
	[db executeUpdate:@"DELETE FROM playlist_items" withArguments:nil];
	[db executeUpdate:@"DELETE FROM playlists" withArguments:nil];
	[db executeUpdate:@"DELETE FROM songs" withArguments:nil];
	[db commitTransaction];
	[_tableView reloadData];
}

- (NSInteger)songCount {
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:@"SELECT COUNT(*) AS c FROM songs" withArguments:nil];
	return [rows count] == 0 ? 0 : [[[rows objectAtIndex:0] objectForKey:@"c"] integerValue];
}

- (NSInteger)playlistCount {
	NSArray *rows = [[LTDatabase sharedDatabase] executeQuery:@"SELECT COUNT(*) AS c FROM playlists" withArguments:nil];
	return [rows count] == 0 ? 0 : [[[rows objectAtIndex:0] objectForKey:@"c"] integerValue];
}

- (NSString *)artworkCacheSizeDescription {
	NSArray *cachesPaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
	NSString *artworkDir = [[cachesPaths objectAtIndex:0] stringByAppendingPathComponent:@"Artwork"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSArray *files = [fileManager contentsOfDirectoryAtPath:artworkDir error:NULL];

	unsigned long long totalBytes = 0;
	for (NSString *file in files) {
		NSDictionary *attributes = [fileManager attributesOfItemAtPath:[artworkDir stringByAppendingPathComponent:file] error:NULL];
		totalBytes += [[attributes objectForKey:NSFileSize] unsignedLongLongValue];
	}
	double megabytes = totalBytes / (1024.0 * 1024.0);
	return [NSString stringWithFormat:@"%d images, %.1f MB", (int)[files count], megabytes];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return LTSettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	switch (section) {
		case LTSettingsSectionLibrary: return 1;
		case LTSettingsSectionStatistics: return 2;
		case LTSettingsSectionStorage: return 1;
		case LTSettingsSectionDangerZone: return 1;
		case LTSettingsSectionAbout: return 2;
		default: return 0;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	switch (section) {
		case LTSettingsSectionLibrary: return @"Library";
		case LTSettingsSectionStatistics: return @"Statistics";
		case LTSettingsSectionStorage: return @"Storage";
		case LTSettingsSectionDangerZone: return @"Danger Zone";
		case LTSettingsSectionAbout: return @"About";
		default: return nil;
	}
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == LTSettingsSectionAbout) {
		return @"Not yet implemented: Home tab, playback engine, light/dark theme toggle, folder/file import, smart playlists/recommendations. Everything else on this screen works.";
	}
	return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *cellIdentifier = @"LTSettingsCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellIdentifier] autorelease];

		// FIX (this is the actual white-on-white cause): grouped-style
		// UITableViewCell draws its own rounded-rect chrome as an image
		// UNDER the content, and plain `cell.backgroundColor` frequently
		// does NOT override that chrome on grouped cells the way it does
		// on plain-style cells — a known iOS 3–6 quirk specific to
		// UITableViewStyleGrouped. The correct override point is
		// `backgroundView` (and `selectedBackgroundView` to match), not
		// `backgroundColor`. Without this, the cell behind the white
		// system chrome was invisible against white text = white-on-white.
		UIView *bg = [[UIView alloc] init];
		bg.backgroundColor = [UIColor colorWithWhite:0.11f alpha:1.0f];
		cell.backgroundView = bg;
		[bg release];

		UIView *selectedBg = [[UIView alloc] init];
		selectedBg.backgroundColor = [UIColor colorWithWhite:0.2f alpha:1.0f];
		cell.selectedBackgroundView = selectedBg;
		[selectedBg release];
	}

	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	cell.textLabel.textColor = [UIColor whiteColor];
	cell.detailTextLabel.textColor = [UIColor lightGrayColor];

	switch (indexPath.section) {
		case LTSettingsSectionLibrary:
			cell.textLabel.text = @"Rescan Library";
			cell.detailTextLabel.text = _isScanning ? @"Scanning…" : @"Idle";
			cell.selectionStyle = _isScanning ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleBlue;
			break;
		case LTSettingsSectionStatistics:
			if (indexPath.row == 0) {
				cell.textLabel.text = @"Songs";
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)[self songCount]];
			} else {
				cell.textLabel.text = @"Playlists";
				cell.detailTextLabel.text = [NSString stringWithFormat:@"%d", (int)[self playlistCount]];
			}
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			break;
		case LTSettingsSectionStorage:
			cell.textLabel.text = @"Clear Artwork Cache";
			cell.detailTextLabel.text = [self artworkCacheSizeDescription];
			break;
		case LTSettingsSectionDangerZone:
			cell.textLabel.text = @"Reset Database";
			cell.textLabel.textColor = [UIColor redColor];
			cell.detailTextLabel.text = nil;
			break;
		case LTSettingsSectionAbout:
			if (indexPath.row == 0) {
				cell.textLabel.text = @"Version";
				cell.detailTextLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
			} else {
				cell.textLabel.text = @"Build Tier";
				cell.detailTextLabel.text = @"A — ARMv6, iOS 3.0–4.3";
			}
			cell.selectionStyle = UITableViewCellSelectionStyleNone;
			break;
		default:
			break;
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	switch (indexPath.section) {
		case LTSettingsSectionLibrary: [self rescanTapped]; break;
		case LTSettingsSectionStorage: [self clearArtworkCacheTapped]; break;
		case LTSettingsSectionDangerZone: [self resetDatabaseTapped]; break;
		default: break;
	}
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[_tableView release];
	[super dealloc];
}

@end
