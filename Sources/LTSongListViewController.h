#import <UIKit/UIKit.h>

@interface LTSongListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UITableView *_tableView;
	NSArray *_songs;
	NSString *_filterColumn;
	NSString *_filterValue;
}

- (id)initWithFilterColumn:(NSString *)column value:(NSString *)value title:(NSString *)title;

@end
