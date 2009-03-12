#import "DeliciousAccount.h"
#import "DeliciousConstants.h"
#import "HGSBundle.h"
#import "HGSLog.h"
#import "GTMBase64.h"

static NSString *const kSetUpDeliciousAccountViewNibName
  = @"SetUpDeliciousAccountView";
static NSString *const kDeliciousURLString = @"http://delicious.com/";
static NSString *const kDeliciousAccountTypeName = @"Delicious";

@interface DeliciousAccount ()

// Open delicious.com in the user's preferred browser.
+ (BOOL)openDeliciousHomePage;

@end

@implementation DeliciousAccount

+ (NSString *)accountType {
  return kDeliciousAccountTypeName;
}

+ (NSView *)setupViewToInstallWithParentWindow:(NSWindow *)parentWindow {
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
	BOOL authenticated = NO;
	// Test this account to see if we can connect.
	NSString *userName = [self userName];
	NSURLRequest *accountRequest = [self accountURLRequestForUserName:userName
															 password:password];
	if (accountRequest) {
		NSURLResponse *accountResponse = nil;
		NSError *error = nil;
		[NSURLConnection sendSynchronousRequest:accountRequest
							  returningResponse:&accountResponse
										  error:&error];
		authenticated = (error == nil);
	}
	return authenticated;
	
	return YES;
}

- (NSURLRequest *)accountURLRequestForUserName:(NSString *)userName
                                      password:(NSString *)password {	
	NSURL *accountTestURL = [NSURL URLWithString:kLastUpdateURL];
	NSMutableURLRequest *accountRequest
    = [NSMutableURLRequest requestWithURL:accountTestURL
                              cachePolicy:NSURLRequestUseProtocolCachePolicy
                          timeoutInterval:15.0];
	NSString *authStr = [NSString stringWithFormat:@"%@:%@",
						 userName, password];
	NSData *authData = [authStr dataUsingEncoding:NSASCIIStringEncoding];
	NSString *authBase64 = [GTMBase64 stringByEncodingData:authData];
	NSString *authValue = [NSString stringWithFormat:@"Basic %@", authBase64];
	[accountRequest setValue:authValue forHTTPHeaderField:@"Authorization"];
	[accountRequest setValue: kPluginUserAgent forHTTPHeaderField:@"User-Agent"];

	return accountRequest;
}

+ (BOOL)openDeliciousHomePage {
  NSURL *deliciousURL = [NSURL URLWithString:kDeliciousURLString];
  BOOL success = [[NSWorkspace sharedWorkspace] openURL:deliciousURL];
  return success;
}

#pragma mark NSURLConnection Delegate Methods

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	HGSAssert(connection == [self connection], nil);
	[self setConnection:nil];
	[self setAuthenticated:YES];
}

@end
 

@implementation DeliciousAccountEditController

- (IBAction)goToDelicious:(id)sender {
  BOOL success = [DeliciousAccount openDeliciousHomePage];
  if (!success) {
    NSBeep();
  }
}

@end

@implementation SetUpDeliciousAccountViewController

- (id)initWithNibName:(NSString *)nibNameOrNil
               bundle:(NSBundle *)nibBundleOrNil {
  self = [super initWithNibName:nibNameOrNil
                         bundle:nibBundleOrNil
               accountTypeClass:[DeliciousAccount class]];
  return self;
}

- (IBAction)goToDelicious:(id)sender {
  BOOL success = [DeliciousAccount openDeliciousHomePage];
  if (!success) {
    NSBeep();
  }
}

@end
