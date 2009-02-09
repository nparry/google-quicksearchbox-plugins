#import "DeliciousAccount.h"
#import "HGSAccountsExtensionPoint.h"
#import "HGSBundle.h"
#import "HGSLog.h"
#import "KeychainItem.h"

static NSString *const kSetUpDeliciousAccountViewNibName
  = @"SetUpDeliciousAccountView";
static NSString *const kDeliciousAccountTypeName = @"Delicious";;

// A class which manages a Delicious account.
@interface DeliciousAccount : HGSSimpleAccount

@end

@implementation DeliciousAccount

+ (NSString *)accountType {
  return kDeliciousAccountTypeName;
}

+ (NSView *)accountSetupViewToInstallWithParentWindow:(NSWindow *)parentWindow {
  static HGSSetUpSimpleAccountViewController *sSetUpDeliciousAccountViewController = nil;
  if (!sSetUpDeliciousAccountViewController) {
    NSBundle *ourBundle = HGSGetPluginBundle();
    HGSSetUpSimpleAccountViewController *loadedViewController
      = [[[SetUpDeliciousAccountViewController alloc]
          initWithNibName:kSetUpDeliciousAccountViewNibName bundle:ourBundle]
         autorelease];
    if (loadedViewController) {
      [loadedViewController loadView];
      sSetUpDeliciousAccountViewController = [loadedViewController retain];
    } else {
      HGSLog(@"Failed to load nib '%@'.", kSetUpDeliciousAccountViewNibName);
    }
  }
  [sSetUpDeliciousAccountViewController setParentWindow:parentWindow];
  return [sSetUpDeliciousAccountViewController view];
}

- (NSString *)editNibName {
  return @"EditDeliciousAccount";
}

- (BOOL)authenticateWithPassword:(NSString *)password {
  // TODO
  [self setIsAuthenticated:YES];
  return YES;  // Return as convenience.
}

@end

@implementation DeliciousAccountEditController

@end

@implementation SetUpDeliciousAccountViewController

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil
                         bundle:nibBundleOrNil
               accountTypeClass:[DeliciousAccount class]];
  return self;
}

@end
