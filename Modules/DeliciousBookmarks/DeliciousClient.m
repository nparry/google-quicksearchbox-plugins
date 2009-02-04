//
//  DeliciousClient.m
//
//  Copyright (c) 2009 Nathan Parry. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are
//  met:
//
//    * Redistributions of source code must retain the above copyright
//  notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
//  copyright notice, this list of conditions and the following disclaimer
//  in the documentation and/or other materials provided with the
//  distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
//  "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
//  LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
//  A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
//  OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
//  LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
//  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
//  THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
//  (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//

#import "DeliciousClient.h"

static NSString *const kLastUpdateURL 
	= @"https://api.del.icio.us/v1/posts/update";

static NSString *const kAllBookmarksURL 
	= @"https://api.del.icio.us/v1/posts/all";

static NSString *const kPluginUserAgent
	= @"GoogleQuickSearchBoxDeliciousPlugin/0.2";

@interface DeliciousClient (PrivateMethods)
- (void)runUpdateCycle;
- (NSString *)parseForLastUpdateDate:(NSData *)data;
- (NSArray *)parseForBookmarks:(NSData *)data;
- (void)openConnectionTo:(NSString *)urlString;
@end

@implementation DeliciousBookmark

-(id)initWithName:(NSString *)aName
			  url:(NSString *)aUrl
			 tags:(NSArray *)theTags {
	if ((self = [super init])) {
		name = [aName retain];
		url =  [aUrl retain];
		tags = [[NSSet setWithArray:theTags] retain];
	}
	return self;
}

- (void)dealloc {
	[name release];
	[url release];
	[tags release];
	
	[super dealloc];
}

@synthesize name;
@synthesize url;
@synthesize tags;

@end

@implementation DeliciousClient
- (id)initWithUsername:(NSString *)username password:(NSString *) password {
	if ((self = [super init])) {
		username_ = [username retain];
		password_ = [password retain];
		lastUpdate_ = nil;
		connection_ = nil;
		dataBuffer_ = nil;
	}
	return self;
}

- (void)dealloc {
	[username_ release];
	[password_ release];
	[lastUpdate_ release];
	[connection_ release];
	[dataBuffer_ release];
	
	[super dealloc];
}

- (void) returnUpdatedDataTo:(id)delegate
	   handleNewDataSelector:(SEL)newDataSelector
	  handleNoChangeSelector:(SEL)noChangeSelector
	   handleFailureSelector:(SEL)failureSelector {
	delegate_ = delegate;
	newDataSelector_ = newDataSelector;
	noChangeSelector_ = noChangeSelector;
	failureSelector_ = failureSelector;
	
	[self runUpdateCycle];
}

- (void) cancelUpdate {
	if (connection_) {
		[connection_ cancel];
		[connection_ release];
		connection_ = nil;
	}
}

@end

@implementation DeliciousClient (PrivateMethods)

#pragma mark Bookmark update lifecycle

- (void)runUpdateCycle {
	connectionCompleteCallbackSelector_ = @selector(handleLastUpdateRsp:);
	[self openConnectionTo:kLastUpdateURL];
}

- (void)handleLastUpdateRsp:(NSData *)data {	
	NSString *newLastUpdate = [self parseForLastUpdateDate:data];
	BOOL upToDate = lastUpdate_ && [lastUpdate_ isEqualToString:newLastUpdate];
	[lastUpdate_ release];
	lastUpdate_ = [newLastUpdate retain];
	
	if (upToDate) {
		[delegate_ performSelector:noChangeSelector_];
	}
	else {
		connectionCompleteCallbackSelector_ = @selector(handleBookmarkFetchRsp:);
		[self openConnectionTo:kAllBookmarksURL];
	}
}

- (void)handleBookmarkFetchRsp:(NSData *)data {
	NSArray *bookmarks = [self parseForBookmarks:data];
	[delegate_ performSelector:newDataSelector_ withObject:bookmarks withObject:username_];
}

#pragma mark -
#pragma mark Delicious response parsing

- (NSString *)parseForLastUpdateDate:(NSData *)data {
	NSXMLDocument* bookmarksXML =
		[[[NSXMLDocument alloc] initWithData:data
									 options:0
									   error:nil] autorelease];
	NSArray *updateNodes = [bookmarksXML nodesForXPath:@"//update" error:NULL];
	return [[(NSXMLElement*)[updateNodes objectAtIndex:0] attributeForName:@"time"] stringValue];
	
}

- (NSArray *)parseForBookmarks:(NSData *)data {
	NSXMLDocument* bookmarksXML =
		[[[NSXMLDocument alloc] initWithData:data
									 options:0
									   error:nil] autorelease];
	NSArray *bookmarkNodes = [bookmarksXML nodesForXPath:@"//post" error:NULL];
	NSMutableArray *bookmarks = [[[NSMutableArray alloc] init] autorelease];
	NSXMLElement *bookmarkNode = nil;
	for (bookmarkNode in bookmarkNodes) {
		NSString *name = [[bookmarkNode attributeForName: @"description"] stringValue];
		NSString *url =  [[bookmarkNode attributeForName: @"href"] stringValue];
		NSArray *tags = [[[bookmarkNode attributeForName:@"tag"] stringValue]
				 componentsSeparatedByString:@" "];		
		DeliciousBookmark *bookmark = [[[DeliciousBookmark alloc]
										initWithName:name url:url tags:tags] autorelease];
		[bookmarks addObject: bookmark];
	}
	
	return bookmarks;
}

#pragma mark -
#pragma mark Http processing

- (void)openConnectionTo:(NSString *)urlString {
	[connection_ release];
	
	NSURL *url = [NSURL URLWithString:urlString];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
	[request setValue: kPluginUserAgent forHTTPHeaderField:@"User-Agent"];
	
	connection_ = [[NSURLConnection connectionWithRequest:request delegate:self] retain];
}

- (void)connection:(NSURLConnection *)connection 
didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
	
	id<NSURLAuthenticationChallengeSender> sender = [challenge sender];
	if ([challenge previousFailureCount] < 3) {
		NSURLCredential *creds 
		= [NSURLCredential credentialWithUser:username_
									 password:password_
								  persistence:NSURLCredentialPersistenceForSession];
		[sender useCredential:creds forAuthenticationChallenge:challenge];
	} else {
		[sender continueWithoutCredentialForAuthenticationChallenge:challenge];
	}
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
	[dataBuffer_ release];
	dataBuffer_ = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
	[dataBuffer_ appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	[self performSelector:connectionCompleteCallbackSelector_ withObject:dataBuffer_];
	[dataBuffer_ release];
	dataBuffer_ = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
	[delegate_ performSelector:failureSelector_ withObject:error];
	[dataBuffer_ release];
	dataBuffer_ = nil;
}

#pragma mark -
@end
