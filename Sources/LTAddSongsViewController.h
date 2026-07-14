#import <UIKit/UIKit.h>

@class LTPlaylist;

// Lists every song in the library; tapping one adds it to the given
// playlist (checkmark shows current membership). Add-only in this pass —
// use the playlist detail screen's swipe-to-delete to remove a song.
@interface LTAddSongsViewController : UIViewController <UITableViewDataSource, UITableViewDelegate> {
	LTPlaylist *_playlist;
	UITableView *_tableView;
	NSArray *_allSongs;
	NSMutableSet *_addedSongIds;
}

- (id)initWithPlaylist:(LTPlaylist *)playlist;

@end
