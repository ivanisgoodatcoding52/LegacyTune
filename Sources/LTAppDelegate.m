#import "LTAppDelegate.h"
#import "LTRootContainerController.h"
#import "LTDatabase.h"
#import "LTLibraryScanner.h"

@implementation LTAppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	[[LTDatabase sharedDatabase] open];

	self.window = [[[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]] autorelease];
	_rootController = [[LTRootContainerController alloc] init];

	if ([self.window respondsToSelector:@selector(setRootViewController:)]) {
		self.window.rootViewController = _rootController;
	} else {
		[self.window addSubview:_rootController.view];
	}

	[self.window makeKeyAndVisible];

	// Scanning is triggered from -applicationDidBecomeActive: below, not
	// here — that fires on cold launch too (after this method returns)
	// AND every time the app returns to the foreground, so the library
	// stays in sync with anything added since the last time the app was
	// open, closer to how the stock Music app kept its index current.
	return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	[[LTLibraryScanner sharedScanner] startScan];
}

- (void)dealloc {
	[_rootController release];
	[_window release];
	[super dealloc];
}

@end
