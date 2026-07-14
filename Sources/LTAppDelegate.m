#import "LTAppDelegate.h"
#import "LTRootContainerController.h"
#import "LTDatabase.h"
#import "LTLibraryScanner.h"

@implementation LTAppDelegate

@synthesize window = _window;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	// Must happen before anything else touches the DB — every view
	// controller assumes it's already open.
	[[LTDatabase sharedDatabase] open];

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

	// Kick off the library scan after the UI is already up, so cold-launch
	// time (spec target: <2s) isn't blocked on it. The scanner posts
	// LTLibraryScannerDidFinishNotification when done; LTLibraryViewController
	// listens for that and reloads itself.
	[[LTLibraryScanner sharedScanner] startScan];

	return YES;
}

- (void)dealloc {
	[_rootController release];
	[_window release];
	[super dealloc];
}

@end
