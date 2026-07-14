#import <Foundation/Foundation.h>

@interface LTSong : NSObject {
	NSInteger _songId;
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
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *genre;
@property (nonatomic, assign) NSInteger trackNumber;
@property (nonatomic, assign) NSInteger discNumber;
@property (nonatomic, assign) NSTimeInterval duration;
@property (nonatomic, copy) NSString *artworkPath;
@property (nonatomic, assign) BOOL favorite;

// row is a dictionary as returned by LTDatabase -executeQuery:withArguments:,
// keyed by column name.
+ (id)songWithRow:(NSDictionary *)row;

@end
