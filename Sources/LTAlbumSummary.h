#import <Foundation/Foundation.h>

// Lightweight, non-persisted summary of one album's grid tile: a
// representative artist and artwork path, derived from its songs. Not
// stored anywhere — built fresh each time the album grid queries.
@interface LTAlbumSummary : NSObject {
	NSString *_album;
	NSString *_artist;
	NSString *_artworkPath;
}

@property (nonatomic, copy) NSString *album;
@property (nonatomic, copy) NSString *artist;
@property (nonatomic, copy) NSString *artworkPath;

+ (id)summaryWithRow:(NSDictionary *)row;

@end
