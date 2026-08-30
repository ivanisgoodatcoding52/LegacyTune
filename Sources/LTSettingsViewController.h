#import <UIKit/UIKit.h>

@interface LTSettingsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate> {
	UITableView *_tableView;
	BOOL _isScanning;
}

@end
