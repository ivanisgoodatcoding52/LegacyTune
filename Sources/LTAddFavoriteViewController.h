#import <UIKit/UIKit.h>

// Pushed screen: segmented Artist/Album toggle + a plain list of every
// artist or album in the library; tapping one adds it as a Favorite and
// pops back. Playlists/Genres favorites were cut from this pass's scope.
@interface LTAddFavoriteViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UISegmentedControl *_typeControl;
	UITableView *_tableView;
	NSArray *_values; // NSString* — distinct artist or album names, depending on _typeControl
}

@end
