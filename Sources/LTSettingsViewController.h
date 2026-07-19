#import <UIKit/UIKit.h>

// Real Settings screen: library management (rescan, clear artwork cache),
// live database statistics, and an About section. Theme/playback/
// recommendation-tuning settings from the original spec are NOT here yet —
// there's nothing to configure until the theme engine and playback engine
// themselves exist, so this deliberately doesn't show controls for
// features that don't do anything.
@interface LTSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate> {
	UITableView *_tableView;
	BOOL _isScanning;
}

@end
