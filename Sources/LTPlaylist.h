#import <Foundation/Foundation.h>

@interface LTPlaylist : NSObject {
	NSInteger _playlistId;
	NSString *_name;
	NSTimeInterval _dateCreated;
}

@property (nonatomic, assign) NSInteger playlistId;
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) NSTimeInterval dateCreated;

+ (id)playlistWithRow:(NSDictionary *)row;

@end
