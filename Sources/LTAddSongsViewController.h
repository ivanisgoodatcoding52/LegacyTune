#import <UIKit/UIKit.h>

@class LTPlaylist;

@interface LTAddSongsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	LTPlaylist *_playlist;
	UITableView *_tableView;
	NSArray *_allSongs;
	NSMutableSet *_addedSongIds;
}

- (id)initWithPlaylist:(LTPlaylist *)playlist;

@end
