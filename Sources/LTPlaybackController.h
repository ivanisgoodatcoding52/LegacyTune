#import <Foundation/Foundation.h>
#import <MediaPlayer/MediaPlayer.h>
#import "LTSong.h"

// Posted on meaningful state changes: song changed, play/pause toggled,
// shuffle/repeat changed. NOT posted on every scrubber tick — screens
// that need smooth playback-time updates (the full player's scrubber)
// should run their own short NSTimer while visible rather than have this
// class broadcast app-wide at high frequency.
extern NSString *const LTPlaybackStateDidChangeNotification;

typedef enum {
	LTRepeatModeOff = 0,
	LTRepeatModeAll,
	LTRepeatModeOne
} LTRepeatMode;

// Wraps MPMusicPlayerController's applicationMusicPlayer as the actual
// decode/output engine — the only playback API that works across our full
// iOS 3.0–4.3 range (AVAudioPlayer needs an ipod-library:// URL, which
// doesn't exist until iOS 4.0). This class owns ITS OWN ordered queue
// (array of LTSong, built from whatever list the user tapped a song in —
// an album, a playlist, search results, etc.) and drives the native
// player through it; shuffle and repeat-all are implemented by us on top
// of that queue, not delegated to the native player's own shuffle/repeat
// (repeat-one is the one exception — see the .m for why).
@interface LTPlaybackController : NSObject {
	MPMusicPlayerController *_player;
	NSMutableArray *_queue;         // LTSong*, the order the user actually chose (e.g. album track order)
	NSMutableArray *_playbackOrder; // LTSong*, _queue itself (shuffle off) or a shuffled copy (shuffle on) — what's actually indexed by _currentIndex
	NSInteger _currentIndex;
	BOOL _shuffleEnabled;
	LTRepeatMode _repeatMode;
	BOOL _isAwaitingFirstNowPlayingNotification;
	NSDictionary *_persistentIdToMediaItem; // built lazily, see .m
}

+ (LTPlaybackController *)sharedController;

// Starts playing `songs` (in the given order) beginning at `index`. This
// becomes the new queue, replacing whatever was playing before.
- (void)playSongs:(NSArray *)songs startingAtIndex:(NSUInteger)index;

- (void)togglePlayPause;
- (void)skipToNext;
- (void)skipToPrevious; // VLC/Spotify convention: restarts current song instead of going back if >3s in
- (void)seekToTime:(NSTimeInterval)time;

@property (nonatomic, assign) BOOL shuffleEnabled; // custom setter, not a plain @synthesize — see .m
- (void)cycleRepeatMode; // Off -> All -> One -> Off

@property (nonatomic, readonly) LTRepeatMode repeatMode;
@property (nonatomic, readonly) BOOL isPlaying;
@property (nonatomic, readonly) NSTimeInterval currentPlaybackTime;
- (LTSong *)currentSong; // nil if nothing queued

@end
