#import "LTPlaybackController.h"

NSString *const LTPlaybackStateDidChangeNotification = @"LTPlaybackStateDidChangeNotification";

@interface LTPlaybackController (Private)
- (void)ensureMediaItemCache;
- (void)playCurrentIndexFromScratch;
- (void)playCurrentIndexFromScratchPreservingTime:(NSTimeInterval)preservedTime;
- (void)nowPlayingItemChanged:(NSNotification *)notification;
- (void)playbackStateChanged:(NSNotification *)notification;
- (void)postStateChanged;
@end

@implementation LTPlaybackController

static LTPlaybackController *_sharedController = nil;

+ (LTPlaybackController *)sharedController {
	if (_sharedController == nil) _sharedController = [[LTPlaybackController alloc] init];
	return _sharedController;
}

- (id)init {
	self = [super init];
	if (self) {
		_player = [[MPMusicPlayerController applicationMusicPlayer] retain];

		// Don't inherit whatever mode the system's own Music app happens
		// to be in — applicationMusicPlayer is independent of it, but
		// starts with whatever shuffle/repeat state it last had unless we
		// explicitly reset both here.
		[_player setShuffleMode:MPMusicShuffleModeOff];
		[_player setRepeatMode:MPMusicRepeatModeNone];

		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(nowPlayingItemChanged:)
			name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:_player];
		[nc addObserver:self selector:@selector(playbackStateChanged:)
			name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:_player];

		// REQUIRED — without this call, the two notifications above never
		// fire, silently. Confirmed against Apple's own "Using Media
		// Playback" guide and multiple independent iPhone OS 3.0-era
		// references; easy to miss since there's no compile-time signal
		// that it's needed.
		[_player beginGeneratingPlaybackNotifications];

		_currentIndex = -1;
		_repeatMode = LTRepeatModeOff;
	}
	return self;
}

#pragma mark - Media item cache

// Maps persistent_id (as our scanner formats it: %llu of the unsigned
// 64-bit persistentID) to the real MPMediaItem, so a queue built from our
// own SQLite-backed LTSong objects can be handed to MPMusicPlayerController,
// which needs actual MPMediaItems, not just metadata. Built synchronously
// on whichever thread first calls -playSongs:startingAtIndex: — this is
// just dictionary construction (no artwork decode/disk I/O, unlike the
// library scanner), so it stays fast even for a few thousand songs. If
// that assumption ever stops holding on a very large library, move this
// to a background thread + callback, same pattern as LTLibraryScanner.
- (void)ensureMediaItemCache {
	if (_persistentIdToMediaItem != nil) return;

	MPMediaQuery *query = [MPMediaQuery songsQuery];
	NSArray *items = [query items];

	NSMutableDictionary *cache = [NSMutableDictionary dictionaryWithCapacity:[items count]];
	for (MPMediaItem *item in items) {
		// Must exactly match the formatting LTLibraryScanner uses when it
		// writes persistent_id into the songs table, or lookups here will
		// silently miss.
		NSNumber *persistentIDNumber = [item valueForProperty:MPMediaItemPropertyPersistentID];
		NSString *persistentID = [NSString stringWithFormat:@"%llu", [persistentIDNumber unsignedLongLongValue]];
		[cache setObject:item forKey:persistentID];
	}
	_persistentIdToMediaItem = [cache retain];
}

#pragma mark - Playing

- (void)playSongs:(NSArray *)songs startingAtIndex:(NSUInteger)index {
	if ([songs count] == 0 || index >= [songs count]) return;
	[self ensureMediaItemCache];

	[_queue release];
	_queue = [songs mutableCopy];

	if (_shuffleEnabled) {
		LTSong *startingSong = [songs objectAtIndex:index];
		NSMutableArray *rest = [NSMutableArray arrayWithArray:songs];
		[rest removeObjectAtIndex:index];

		NSUInteger count = [rest count];
		for (NSUInteger i = count; i > 1; i--) {
			NSUInteger j = arc4random() % i;
			[rest exchangeObjectAtIndex:(i - 1) withObjectAtIndex:j];
		}

		NSMutableArray *order = [NSMutableArray arrayWithObject:startingSong];
		[order addObjectsFromArray:rest];
		[_playbackOrder release];
		_playbackOrder = [order retain];
		_currentIndex = 0;
	} else {
		[_playbackOrder release];
		_playbackOrder = [_queue mutableCopy];
		_currentIndex = index;
	}

	[self playCurrentIndexFromScratch];
}

// Builds an MPMediaItemCollection covering _currentIndex through the end
// of _playbackOrder (not the whole thing — just what's left to play), and
// hands it to the native player. This deliberately does NOT rely on
// MPMusicPlayerController's own -indexOfNowPlayingItem, which is iOS
// 5.0+ only; giving it exactly "what's left, in our order" and then
// tracking natural advances ourselves (see -nowPlayingItemChanged:) works
// correctly all the way back to iOS 3.0.
- (void)playCurrentIndexFromScratch {
	[self playCurrentIndexFromScratchPreservingTime:0];
}

- (void)playCurrentIndexFromScratchPreservingTime:(NSTimeInterval)preservedTime {
	if (_playbackOrder == nil || _currentIndex < 0 || (NSUInteger)_currentIndex >= [_playbackOrder count]) return;

	NSMutableArray *items = [NSMutableArray array];
	for (NSUInteger i = (NSUInteger)_currentIndex; i < [_playbackOrder count]; i++) {
		LTSong *song = [_playbackOrder objectAtIndex:i];
		MPMediaItem *item = [_persistentIdToMediaItem objectForKey:song.persistentId];
		if (item != nil) [items addObject:item];
	}
	if ([items count] == 0) return;

	MPMediaItemCollection *collection = [MPMediaItemCollection collectionWithItems:items];

	// Repeat-one is the one case we delegate to the native player instead
	// of handling ourselves — it natively repeats whatever the current
	// nowPlayingItem is without needing us to detect anything.
	[_player setRepeatMode:(_repeatMode == LTRepeatModeOne) ? MPMusicRepeatModeOne : MPMusicRepeatModeNone];

	_isAwaitingFirstNowPlayingNotification = YES;
	[_player stop];
	[_player setQueueWithItemCollection:collection];
	[_player play];

	if (preservedTime > 0) {
		// Best-effort: on some devices this can race with the player not
		// yet being ready for a seek immediately after -play. Not
		// correctness-critical (worst case: shuffle toggle restarts the
		// current song from 0:00 instead of preserving position), so not
		// worth a more complex ready-callback just for this nicety.
		[_player setCurrentPlaybackTime:preservedTime];
	}

	[self postStateChanged];
}

- (void)togglePlayPause {
	if (_player.playbackState == MPMusicPlaybackStatePlaying) {
		[_player pause];
	} else {
		[_player play];
	}
}

- (void)skipToNext {
	if (_playbackOrder == nil) return;

	if (_currentIndex + 1 < (NSInteger)[_playbackOrder count]) {
		_currentIndex++;
		[self playCurrentIndexFromScratch];
	} else if (_repeatMode == LTRepeatModeAll && [_playbackOrder count] > 0) {
		_currentIndex = 0;
		[self playCurrentIndexFromScratch];
	}
	// else: already at the end with repeat off — no-op.
}

- (void)skipToPrevious {
	// VLC/Spotify convention: more than ~3s into the song restarts it
	// instead of actually going back a track.
	if ([_player currentPlaybackTime] > 3.0) {
		[_player setCurrentPlaybackTime:0];
		[self postStateChanged];
		return;
	}

	if (_currentIndex > 0) {
		_currentIndex--;
		[self playCurrentIndexFromScratch];
	} else {
		[_player setCurrentPlaybackTime:0];
		[self postStateChanged];
	}
}

- (void)seekToTime:(NSTimeInterval)time {
	[_player setCurrentPlaybackTime:time];
	[self postStateChanged];
}

#pragma mark - Shuffle / repeat

- (BOOL)shuffleEnabled {
	return _shuffleEnabled;
}

- (void)setShuffleEnabled:(BOOL)enabled {
	if (_shuffleEnabled == enabled) return;
	_shuffleEnabled = enabled;
	if (_queue == nil || [_queue count] == 0) return; // nothing playing yet — just remember the preference for next -playSongs:

	NSTimeInterval preservedTime = [_player currentPlaybackTime];
	LTSong *currentSong = [self currentSong];

	if (enabled) {
		NSMutableArray *rest = [NSMutableArray arrayWithArray:_queue];
		if (currentSong != nil) [rest removeObject:currentSong];

		NSUInteger count = [rest count];
		for (NSUInteger i = count; i > 1; i--) {
			NSUInteger j = arc4random() % i;
			[rest exchangeObjectAtIndex:(i - 1) withObjectAtIndex:j];
		}

		NSMutableArray *order = [NSMutableArray array];
		if (currentSong != nil) [order addObject:currentSong];
		[order addObjectsFromArray:rest];
		[_playbackOrder release];
		_playbackOrder = [order retain];
		_currentIndex = 0;
	} else {
		[_playbackOrder release];
		_playbackOrder = [_queue mutableCopy];
		NSUInteger foundIndex = (currentSong != nil) ? [_playbackOrder indexOfObject:currentSong] : NSNotFound;
		_currentIndex = (foundIndex != NSNotFound) ? (NSInteger)foundIndex : 0;
	}

	[self playCurrentIndexFromScratchPreservingTime:preservedTime];
}

- (LTRepeatMode)repeatMode {
	return _repeatMode;
}

- (void)cycleRepeatMode {
	switch (_repeatMode) {
		case LTRepeatModeOff: _repeatMode = LTRepeatModeAll; break;
		case LTRepeatModeAll: _repeatMode = LTRepeatModeOne; break;
		case LTRepeatModeOne: _repeatMode = LTRepeatModeOff; break;
	}
	// Only repeat-one needs to touch the native player immediately
	// (native repeat state persists across pause/resume without us
	// rebuilding anything); off/all are enforced by our own end-of-queue
	// handling in -nowPlayingItemChanged:, not the native repeatMode.
	[_player setRepeatMode:(_repeatMode == LTRepeatModeOne) ? MPMusicRepeatModeOne : MPMusicRepeatModeNone];
	[self postStateChanged];
}

#pragma mark - State

- (BOOL)isPlaying {
	return _player.playbackState == MPMusicPlaybackStatePlaying;
}

- (NSTimeInterval)currentPlaybackTime {
	return [_player currentPlaybackTime];
}

- (LTSong *)currentSong {
	if (_playbackOrder == nil || _currentIndex < 0 || (NSUInteger)_currentIndex >= [_playbackOrder count]) return nil;
	return [_playbackOrder objectAtIndex:(NSUInteger)_currentIndex];
}

#pragma mark - Notifications from the native player

- (void)nowPlayingItemChanged:(NSNotification *)notification {
	MPMediaItem *nowPlayingItem = _player.nowPlayingItem;

	if (nowPlayingItem == nil) {
		// Natural end of the collection we handed it (confirmed: on this
		// era of iOS, nowPlayingItem going nil is how end-of-queue is
		// signaled — that detection method changed in iOS 12+, long
		// after our target range).
		_isAwaitingFirstNowPlayingNotification = NO;
		if (_repeatMode == LTRepeatModeAll && [_playbackOrder count] > 0) {
			_currentIndex = 0;
			[self playCurrentIndexFromScratch];
		} else {
			[self postStateChanged];
		}
		return;
	}

	if (_isAwaitingFirstNowPlayingNotification) {
		// This is confirmation of the song WE just told it to play, not a
		// natural forward advance — don't increment past it.
		_isAwaitingFirstNowPlayingNotification = NO;
	} else if (_currentIndex + 1 < (NSInteger)[_playbackOrder count]) {
		// We always hand the native player our remaining songs in exact
		// order, so a natural advance within that collection means
		// "the next song in _playbackOrder is now playing."
		_currentIndex++;
	}

	[self postStateChanged];
}

- (void)playbackStateChanged:(NSNotification *)notification {
	[self postStateChanged];
}

- (void)postStateChanged {
	[[NSNotificationCenter defaultCenter] postNotificationName:LTPlaybackStateDidChangeNotification object:self];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MPMusicPlayerControllerNowPlayingItemDidChangeNotification object:_player];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:MPMusicPlayerControllerPlaybackStateDidChangeNotification object:_player];
	[_player endGeneratingPlaybackNotifications];
	[_player release];
	[_queue release];
	[_playbackOrder release];
	[_persistentIdToMediaItem release];
	[super dealloc];
}

@end
