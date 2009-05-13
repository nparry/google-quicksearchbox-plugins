#import "DeliciousAccount.h"
#import "DeliciousConstants.h"
#import "HGSBundle.h"
#import "HGSLog.h"
#import "GTMBase64.h"
#import <GData/GDataHTTPFetcher.h>


static NSString *const kDeliciousURLString = @"http://delicious.com/";
static NSString *const kDeliciousAccountTypeName = @"com.google.qsb.delicious.account";

// Authentication timing constants.
static const NSTimeInterval kAuthenticationRetryInterval = 0.1;
static const NSTimeInterval kAuthenticationGiveUpInterval = 30.0;
static const NSTimeInterval kAuthenticationTimeOutInterval = 15.0;


@interface DeliciousAccount ()

// Check the authentication response to see if the account authenticated.
- (BOOL)validateResponse:(NSURLResponse *)response;

// Open delicious.com in the user's preferred browser.
+ (BOOL)openDeliciousHomePage;

@property (nonatomic, assign) BOOL authCompleted;
@property (nonatomic, assign) BOOL authSucceeded;

@end

@implementation DeliciousAccount

@synthesize authCompleted = authCompleted_;
@synthesize authSucceeded = authSucceeded_;

- (NSString *)type {
  return kDeliciousAccountTypeName;
}

#pragma mark Account Editing

- (void)authenticate {
	NSString *userName = [self userName];
	NSString *password = [self password];
	NSURL *authURL = [NSURL URLWithString:kLastUpdateURL];
	NSMutableURLRequest *authRequest
    = [NSMutableURLRequest requestWithURL:authURL
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                          timeoutInterval:kAuthenticationTimeOutInterval];
	if (authRequest) {
		[authRequest setHTTPShouldHandleCookies:NO];
		GDataHTTPFetcher* authSetFetcher
		= [GDataHTTPFetcher httpFetcherWithRequest:authRequest];
		[authSetFetcher setIsRetryEnabled:YES];
		if ([userName length]) {
			[authSetFetcher setCredential:
			 [NSURLCredential credentialWithUser:userName
										password:password
									 persistence:NSURLCredentialPersistenceNone]];
		}
		[authSetFetcher
		 setCookieStorageMethod:kGDataHTTPFetcherCookieStorageMethodFetchHistory];
		[authSetFetcher beginFetchWithDelegate:self
							 didFinishSelector:@selector(authSetFetcher:
														 finishedWithData:)
							   didFailSelector:@selector(authSetFetcher:
														 failedWithError:)];
	}
}

- (BOOL)authenticateWithPassword:(NSString *)password {
	BOOL authenticated = NO;
	// Test this account to see if we can connect.
	NSString *userName = [self userName];
	NSURL *authURL = [NSURL URLWithString:kLastUpdateURL];
	NSMutableURLRequest *authRequest
    = [NSMutableURLRequest requestWithURL:authURL
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                          timeoutInterval:kAuthenticationTimeOutInterval];
	if (authRequest) {
		[authRequest setHTTPShouldHandleCookies:NO];
		[self setAuthCompleted:NO];
		[self setAuthSucceeded:NO];
		GDataHTTPFetcher* authFetcher
		= [GDataHTTPFetcher httpFetcherWithRequest:authRequest];
		[authFetcher setIsRetryEnabled:YES];
		[authFetcher
		 setCookieStorageMethod:kGDataHTTPFetcherCookieStorageMethodFetchHistory];
		if (userName) {
			[authFetcher setCredential:
			 [NSURLCredential credentialWithUser:userName
										password:password
									 persistence:NSURLCredentialPersistenceNone]];
		}
		[authFetcher beginFetchWithDelegate:self
						  didFinishSelector:@selector(authFetcher:
													  finishedWithData:)
							didFailSelector:@selector(authFetcher:
													  failedWithError:)];
		// Block until this fetch is done to make it appear synchronous. Sleep
		// for a second and then check again until is has completed.  Just in
		// case, put an upper limit of 30 seconds before we bail.
		NSTimeInterval endTime
		= [NSDate timeIntervalSinceReferenceDate] + kAuthenticationGiveUpInterval;
		NSRunLoop* loop = [NSRunLoop currentRunLoop];
		while (![self authCompleted]) {
			NSDate *sleepTilDate
			= [NSDate dateWithTimeIntervalSinceNow:kAuthenticationRetryInterval];
			[loop runUntilDate:sleepTilDate];
			if ([NSDate timeIntervalSinceReferenceDate] > endTime) {
				[authFetcher stopFetching];
				[self setAuthCompleted:YES];
			}
		}
		authenticated = [self authSucceeded];
	}
	return authenticated;
}

- (BOOL)validateResponse:(NSURLResponse *)response {
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

#pragma mark GDataHTTPFetcher Delegate Methods

- (void)authSetFetcher:(GDataHTTPFetcher *)fetcher
      finishedWithData:(NSData *)data {
	NSURLResponse *response = [fetcher response];
	BOOL authenticated = [self validateResponse:response];
	[self setAuthenticated:authenticated];
}

- (void)authSetFetcher:(GDataHTTPFetcher *)fetcher
       failedWithError:(NSError *)error {
	HGSLogDebug(@"Authentication failed for account '%@' (%@), error: '%@' (%d)",
				[self userName], [self type], [error localizedDescription],
				[error code]);
	[self setAuthenticated:NO];
}

- (void)authFetcher:(GDataHTTPFetcher *)fetcher
   finishedWithData:(NSData *)data {
	NSURLResponse *response = [fetcher response];
	BOOL authenticated = [self validateResponse:response];
	[self setAuthCompleted:YES];
	[self setAuthSucceeded:authenticated];
}

- (void)authFetcher:(GDataHTTPFetcher *)fetcher
    failedWithError:(NSError *)error {
	HGSLogDebug(@"Authentication failed for account '%@' (%@), error: '%@' (%d)",
				[self userName], [self type], [error localizedDescription],
				[error code]);
	[self setAuthCompleted:YES];
	[self setAuthSucceeded:NO];
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
