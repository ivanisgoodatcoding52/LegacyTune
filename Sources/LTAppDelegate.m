#import "LTAppDelegate.h"
#import "LTRootContainerController.h"

@implementation LTAppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];

	_rootController = [[LTRootContainerController alloc] init];

	// -[UIWindow setRootViewController:] is iOS 4.0+ only. Since this
	// tier's floor is iOS 3.0, guard it and fall back to adding the
	// controller's view as a plain subview on iOS 3.x.
	if ([self.window respondsToSelector:@selector(setRootViewController:)]) {
		self.window.rootViewController = _rootController;
	} else {
		[self.window addSubview:_rootController.view];
	}

	[self.window makeKeyAndVisible];
	return YES;
}

- (void)dealloc {
	[_rootController release];
	[_window release];
	[super dealloc];
}

@end
