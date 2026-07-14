#import <UIKit/UIKit.h>

// Shows songs matching a single equality filter, e.g. artist = "Radiohead".
// Used by LTLibraryViewController when drilling into an artist/album/genre.
@interface LTSongListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	UITableView *_tableView;
	NSArray *_songs;
	NSString *_filterColumn;
	NSString *_filterValue;
}

// column must be a fixed, developer-controlled string ("artist", "album",
// or "genre" today) — never pass user-typed text as column, since it gets
// interpolated directly into the SQL (only filterValue is parameter-bound).
- (id)initWithFilterColumn:(NSString *)column value:(NSString *)value title:(NSString *)title;

@end
