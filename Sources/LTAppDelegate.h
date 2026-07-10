#import <UIKit/UIKit.h>

@class LTRootContainerController;

@interface LTAppDelegate : NSObject <UIApplicationDelegate> {
	UIWindow *_window;
	LTRootContainerController *_rootController;
}

@property (nonatomic, retain) UIWindow *window;

@end
