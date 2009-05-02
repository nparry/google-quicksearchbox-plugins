#import "DeliciousAccount.h"
#import "DeliciousConstants.h"
#import "HGSBundle.h"
#import "HGSLog.h"
#import "GTMBase64.h"

static NSString *const kDeliciousURLString = @"http://delicious.com/";
static NSString *const kDeliciousAccountTypeName = @"com.google.qsb.delicious.account";

@interface DeliciousAccount ()

// Open delicious.com in the user's preferred browser.
+ (BOOL)openDeliciousHomePage;

@end

@implementation DeliciousAccount

+ (NSString *)type {
  return kDeliciousAccountTypeName;
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

- (BOOL)validateResult:(NSData *)result
              response:(NSURLResponse *)response
                 error:(NSError *)error {
	BOOL valid = NO;
	if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
		NSHTTPURLResponse *httpURLResponse = (NSHTTPURLResponse *)response;
		NSInteger statusCode = [httpURLResponse statusCode];
		// A 200 means verified, a 401 means not verified.
		valid = (statusCode == 200);
	}
	return valid;
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
 

@implementation EditDeliciousAccountWindowController

- (IBAction)openDeliciousHomePage:(id)sender {
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

- (IBAction)openDeliciousHomePage:(id)sender {
  BOOL success = [DeliciousAccount openDeliciousHomePage];
  if (!success) {
    NSBeep();
  }
}

@end
