#import <Foundation/Foundation.h>
#import "LTSong.h"
#import "LTPlaylist.h"

@interface LTPlaylistStore : NSObject
+ (LTPlaylistStore *)sharedStore;
- (NSArray *)allPlaylists;
- (LTPlaylist *)createPlaylistWithName:(NSString *)name;
- (void)renamePlaylist:(LTPlaylist *)playlist to:(NSString *)newName;
- (void)deletePlaylist:(LTPlaylist *)playlist;
- (NSArray *)songsInPlaylist:(LTPlaylist *)playlist;
- (void)addSong:(LTSong *)song toPlaylist:(LTPlaylist *)playlist;
- (void)removeSongAtIndex:(NSUInteger)index fromPlaylist:(LTPlaylist *)playlist;
- (void)moveSongInPlaylist:(LTPlaylist *)playlist fromIndex:(NSUInteger)from toIndex:(NSUInteger)to;
@end
