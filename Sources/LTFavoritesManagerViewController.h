#import <UIKit/UIKit.h>

// Pushed screen (from Home) for managing Favorites: plain list,
// swipe-to-delete to remove, "+" to add. Deliberately NOT the "biggest
// lift" drag-and-drop editor — that scope was reserved for whole-Home-
// section reordering only; individual favorites just need add/remove.
@interface LTFavoritesManagerViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UITableView *_tableView;
	NSArray *_favorites; // LTHomeFavorite*
}

@end
