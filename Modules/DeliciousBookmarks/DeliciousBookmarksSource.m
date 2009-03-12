#import <Vermilion/Vermilion.h>
#import <Vermilion/KeychainItem.h>
#import "DeliciousConstants.h"

static const NSTimeInterval kRefreshSeconds = 3600.0;  // 60 minutes.

// Only report errors to user once an hour.
static const NSTimeInterval kErrorReportingInterval = 3600.0;  // 1 hour

@interface DeliciousBookmarksSource : HGSMemorySearchSource <HGSAccountClientProtocol> {
@private
	NSTimer *updateTimer_;
	NSMutableData *bookmarkData_;
	NSString *lastUpdate_;
	HGSSimpleAccount *account_;
	NSURLConnection *connection_;
	BOOL currentlyFetching_;
	SEL currentCallback_;
	NSTimeInterval previousErrorReportingTime_;
	NSImage *tagIcon_;
}

@property (nonatomic, retain) NSURLConnection *connection;

- (void)setUpPeriodicRefresh;
- (void)startAsynchronousBookmarkFetch:(NSString*)url
							  callback:(SEL)selector
						waitIfFetching:(BOOL)shouldWait;
- (void)checkLastUpdate;
- (void)indexBookmarksFromData;
- (void)indexResultForUrl:(NSString *)url
					title:(NSString *)title
					 type:(NSString *)type
					 tags:(NSArray *)tags
					 icon:(NSImage*)iconImage;

// Post user notification about a connection failure.
- (void)reportConnectionFailure:(NSString *)explanation
                    successCode:(NSInteger)successCode;

@end

@implementation DeliciousBookmarksSource

@synthesize connection = connection_;

- (id)initWithConfiguration:(NSDictionary *)configuration {
	if ((self = [super initWithConfiguration:configuration])) {
		NSBundle* sourceBundle = HGSGetPluginBundle();
		NSString *iconPath = [sourceBundle pathForImageResource:@"delicious"];
		tagIcon_ = [[NSImage alloc] initByReferencingFile:iconPath];		
		account_ = [[configuration objectForKey:kHGSExtensionAccount] retain];
		lastUpdate_ = [@"unknown" retain];
		if (account_) {
			// Fetch, and schedule a timer to update every hour.
			[self startAsynchronousBookmarkFetch:kLastUpdateURL
										callback:@selector(checkLastUpdate)
								  waitIfFetching:true];
			[self setUpPeriodicRefresh];
			// Watch for credential changes.
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			[nc addObserver:self
				   selector:@selector(loginCredentialsChanged:)
					   name:kHGSAccountDidChangeNotification
					 object:account_];
		}
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if ([updateTimer_ isValid]) {
		[updateTimer_ invalidate];
	}
	[updateTimer_ release];
	[bookmarkData_ release];
	[account_ release];
	[lastUpdate_ release];
	[tagIcon_ release];

	[super dealloc];
}


#pragma mark -

- (void)processMatchingResults:(NSMutableArray*)results
                      forQuery:(HGSQuery *)query {
	// Pivot on tags, filter to only bookmarks with that tag
	HGSResult *pivotObject = [query pivotObject];
	if (pivotObject) {
		NSString *tag = [pivotObject displayName];
		NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
		
		NSUInteger resultCount = [results count];
		for (NSUInteger idx = 0; idx < resultCount ; ++idx) {
			HGSResult *result = [results objectAtIndex:idx];
			NSSet *tags = [result valueForKey:kObjectAttributeDeliciousTags];
			if (tags && [tags containsObject:tag]) {
				continue;
			}
			
			[indexesToRemove addIndex:idx];
		}
		
		// remove the indexes that weren't matches
		[results removeObjectsAtIndexes:indexesToRemove];
	}       
}

#pragma mark Bookmarks Fetching

- (void)startAsynchronousBookmarkFetch:(NSString*)url
							  callback:(SEL)selector
						waitIfFetching:(BOOL)shouldWait {
	
	KeychainItem* keychainItem 
    = [KeychainItem keychainItemForService:[account_ identifier]
                                  username:nil];
	NSString *userName = [keychainItem username];
	NSString *password = [keychainItem password];
	if ((!currentlyFetching_ || !shouldWait) && userName && password) {
		NSURL *bookmarkRequestURL = [NSURL URLWithString:url];
		NSMutableURLRequest *bookmarkRequest
		= [NSMutableURLRequest requestWithURL:bookmarkRequestURL 
								  cachePolicy:NSURLRequestReloadIgnoringCacheData 
							  timeoutInterval:15.0];
		[bookmarkRequest setValue: kPluginUserAgent forHTTPHeaderField:@"User-Agent"];
		currentlyFetching_ = YES;
		currentCallback_ = selector;
		NSURLConnection *connection
		= [NSURLConnection connectionWithRequest:bookmarkRequest delegate:self];
		[self setConnection:connection];
	}
}

- (void)refreshBookmarks:(NSTimer *)timer {
	[self startAsynchronousBookmarkFetch:kLastUpdateURL
								callback:@selector(checkLastUpdate)
						  waitIfFetching:true];
}

- (void)checkLastUpdate {
	NSXMLDocument* bookmarksXML =
		[[[NSXMLDocument alloc] initWithData:bookmarkData_
									 options:0
									   error:nil] autorelease];
	NSArray *updateNodes = [bookmarksXML nodesForXPath:@"//update" error:NULL];
	NSString *newLastUpdate = [[(NSXMLElement*)[updateNodes objectAtIndex:0]
								attributeForName:@"time"] stringValue];
	
	BOOL upToDate = lastUpdate_ && [lastUpdate_ isEqualToString:newLastUpdate];
	[lastUpdate_ release];
	lastUpdate_ = [newLastUpdate retain];
	
	[bookmarkData_ release];
	bookmarkData_ = nil;
	
	if (!upToDate) {
		[self startAsynchronousBookmarkFetch:kAllBookmarksURL
									callback:@selector(indexBookmarksFromData)
							  waitIfFetching:false];		
	}
}

- (void)indexBookmarksFromData {
	NSXMLDocument* bookmarksXML 
    = [[[NSXMLDocument alloc] initWithData:bookmarkData_
                                   options:0
                                     error:nil] autorelease];
	NSArray *bookmarkNodes = [bookmarksXML nodesForXPath:@"//post" error:NULL];
	[self clearResultIndex];
	
	NSMutableSet *allTags = [NSMutableSet setWithCapacity:50];
	NSEnumerator *nodeEnumerator = [bookmarkNodes objectEnumerator];
	NSXMLElement *bookmark;
	while ((bookmark = [nodeEnumerator nextObject])) {
		NSString *name = [[bookmark attributeForName: @"description"] stringValue];
		NSString *url =  [[bookmark attributeForName: @"href"] stringValue];
		NSArray *tags = [[[bookmark attributeForName:@"tag"] stringValue]
						 componentsSeparatedByString:@" "];	
		
		[allTags addObjectsFromArray:tags];
		[self indexResultForUrl:url
						 title:name
						  type:HGS_SUBTYPE(kHGSTypeWebBookmark, @"deliciousbookmarks")
						  tags:tags
						  icon:nil];
	}
	
	NSString *username = [[KeychainItem keychainItemForService:[account_ identifier]
													  username:nil] username];
	for (NSString *tag in allTags) {
		NSString *url = [NSString stringWithFormat:@"http://delicious.com/%@/%@", username, tag];
		[self indexResultForUrl:url
						 title:tag
						  type:HGS_SUBTYPE(kHGSTypeWebpage, @"delicioustag")
						  tags: nil
						  icon:tagIcon_];
	}
	
	currentlyFetching_ = NO;	
	[bookmarkData_ release];
	bookmarkData_ = nil;
}

- (void)indexResultForUrl:(NSString *)url
					title:(NSString *)title
					 type:(NSString *)type
					 tags:(NSArray *)tags
					 icon:(NSImage*)iconImage {	
	if (!url) {
		return;
	}
	
	NSNumber *rankFlags = [NSNumber numberWithUnsignedInt:eHGSUnderHomeRankFlag];
	NSMutableDictionary *attributes 
		= [NSMutableDictionary dictionaryWithObjectsAndKeys:
		   rankFlags, kHGSObjectAttributeRankFlagsKey,
		   url, kHGSObjectAttributeSourceURLKey,
		   nil];
	
	if (tags) {
		[attributes setObject:tags forKey:kObjectAttributeDeliciousTags];
	}
	
	if (iconImage) {
		[attributes setObject:iconImage forKey:kHGSObjectAttributeIconKey];
	}
	
	HGSResult* result 
		= [HGSResult resultWithURL:[NSURL URLWithString:url]
							  name:([title length] > 0 ? title : url)
							  type:type
							source:self
						attributes:attributes];
	[self indexResult:result
		   nameString:title
	otherStringsArray:tags];
}

- (void)setConnection:(NSURLConnection *)connection {
	if (connection_ != connection) {
		[connection_ cancel];
		[connection_ release];
		connection_ = [connection retain];
	}
}

#pragma mark -
#pragma mark NSURLConnection Delegate Methods

- (void)connection:(NSURLConnection *)connection 
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	HGSAssert(connection == connection_, nil);
	KeychainItem* keychainItem 
    = [KeychainItem keychainItemForService:[account_ identifier]
                                  username:nil];
	NSString *userName = [keychainItem username];
	NSString *password = [keychainItem password];
	
	id<NSURLAuthenticationChallengeSender> sender = [challenge sender];
	NSInteger previousFailureCount = [challenge previousFailureCount];
	
	if (previousFailureCount > 3) {
		// Don't keep trying.
		[updateTimer_ invalidate];
		NSString *errorFormat
			= HGSLocalizedString(@"Authentication for '%@' failed. Check your "
								 @"password.", nil);
		NSString *errorString = [NSString stringWithFormat:errorFormat,
								 userName];
		[self reportConnectionFailure:errorString successCode:kHGSSuccessCodeError];
		HGSLogDebug(@"DeliciousBookmarkSource authentication failure for account '%@'.",
					userName);
		return;
	}
	
	if (userName && password) {
		NSURLCredential *creds = [NSURLCredential
								  credentialWithUser:userName
											password:password
										 persistence:NSURLCredentialPersistenceNone];
		[sender useCredential:creds forAuthenticationChallenge:challenge];
	} else {
		[sender continueWithoutCredentialForAuthenticationChallenge:challenge];
	}
}

- (void)connection:(NSURLConnection *)connection 
didReceiveResponse:(NSURLResponse *)response {
	HGSAssert(connection == connection_, nil);
	[bookmarkData_ release];
	bookmarkData_ = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection 
    didReceiveData:(NSData *)data {
	HGSAssert(connection == connection_, nil);
	[bookmarkData_ appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	HGSAssert(connection == connection_, nil);
	[self setConnection:nil];
	[self performSelector:currentCallback_];
}

- (void)connection:(NSURLConnection *)connection 
  didFailWithError:(NSError *)error {
	HGSAssert(connection == connection_, nil);
	[self setConnection:nil];
	currentlyFetching_ = NO;
	[bookmarkData_ release];
	bookmarkData_ = nil;
	KeychainItem* keychainItem 
    = [KeychainItem keychainItemForService:[account_ identifier]
                                  username:nil];
	NSString *userName = [keychainItem username];
	NSString *errorFormat
    = HGSLocalizedString(@"Fetch for '%@' failed. (%d)", nil);
	NSString *errorString = [NSString stringWithFormat:errorFormat,
							 userName, [error code]];
	[self reportConnectionFailure:errorString successCode:kHGSSuccessCodeBadError];
	HGSLogDebug(@"DeliciousBookmarkSource connection failure (%d) '%@'.",
				[error code], [error localizedDescription]);
}

#pragma mark Authentication & Refresh

- (void)loginCredentialsChanged:(NSNotification *)notification {
	id <HGSAccount> account = [notification object];
	HGSAssert(account == account_, @"Notification from bad account!");
	// Make sure we aren't in the middle of waiting for results; if we are, try
	// again later instead of changing things in the middle of the fetch.
	if (currentlyFetching_) {
		[self performSelector:@selector(loginCredentialsChanged:)
				   withObject:notification
				   afterDelay:60.0];
		return;
	}
	// If the login changes, we should update immediately, and make sure the
	// periodic refresh is enabled (it would have been shut down if the previous
	// credentials were incorrect).
	[self startAsynchronousBookmarkFetch:kLastUpdateURL
								callback:@selector(checkLastUpdate)
						  waitIfFetching:true];
	[self setUpPeriodicRefresh];
}

- (void)reportConnectionFailure:(NSString *)explanation
                    successCode:(NSInteger)successCode {
	NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
	NSTimeInterval timeSinceLastErrorReport
    = currentTime - previousErrorReportingTime_;
	if (timeSinceLastErrorReport > kErrorReportingInterval) {
		previousErrorReportingTime_ = currentTime;
		NSString *errorSummary = HGSLocalizedString(@"Delicious Bookmarks", nil);
		NSNumber *successNumber = [NSNumber numberWithInt:successCode];
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		NSDictionary *messageDict
		= [NSDictionary dictionaryWithObjectsAndKeys:
		   errorSummary, kHGSSummaryMessageKey,
		   explanation, kHGSDescriptionMessageKey,
		   successNumber, kHGSSuccessCodeMessageKey,
		   nil];
		[nc postNotificationName:kHGSUserMessageNotification 
						  object:self
						userInfo:messageDict];
	}
}

- (void)setUpPeriodicRefresh {
	// Kick off a timer if one is not already running.
	if (![updateTimer_ isValid]) {
		[updateTimer_ release];
		updateTimer_ 
		= [[NSTimer scheduledTimerWithTimeInterval:kRefreshSeconds
											target:self
										  selector:@selector(refreshBookmarks:)
										  userInfo:nil
										   repeats:YES] retain];
	}
}

#pragma mark -
#pragma mark HGSAccountClientProtocol Methods

- (BOOL)accountWillBeRemoved:(id<HGSAccount>)account {
	HGSAssert(account == account_, @"Notification from bad account!");
	return YES;
}

@end
