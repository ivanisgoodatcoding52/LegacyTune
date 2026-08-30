#import <Foundation/Foundation.h>

@interface LTSong : NSObject {
	NSInteger _songId;
	NSString *_persistentId;
	NSString *_title;
	NSString *_artist;
	NSString *_album;
	NSString *_genre;
	NSInteger _trackNumber;
	NSInteger _discNumber;
	NSTimeInterval _duration;
	NSString *_artworkPath;
	BOOL _favorite;
}

@property (nonatomic, assign) NSInteger songId;
// Maps back to the real MPMediaItem for actual playback (see
// LTPlaybackController) — was in the songs table already but never
// exposed on this model until playback needed it.
@property (nonatomic, copy) NSString *persistentId;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *genre;
@property (nonatomic, assign) NSInteger trackNumber;
@property (nonatomic, assign) NSInteger discNumber;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, copy) NSString *artworkPath;
@property (nonatomic, assign) BOOL favorite;

+ (id)songWithRow:(NSDictionary *)row;

@end
