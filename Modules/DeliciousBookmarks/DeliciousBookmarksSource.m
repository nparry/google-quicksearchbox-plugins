//
//  DeliciousBookmarksSource.m
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

#import <Vermilion/Vermilion.h>
#import "KeychainItem.h"
#import "DeliciousClient.h"

static NSString *const kObjectAttributeDeliciousTags 
	= @"ObjectAttributeDeliciousTags";

@interface DeliciousBookmarksSource : HGSMemorySearchSource <HGSAccountClientProtocol> {
	NSTimer *updateTimer_;
	DeliciousClient *deliciousClient_;
	BOOL currentlyFetching_;
	NSString *accountIdentifier_;
	NSImage *tagIcon_;
}
- (void)setUpPeriodicRefresh;
- (void)startAsynchronousBookmarkFetch;
- (void)refreshBookmarks:(NSTimer *)timer;
- (void)loginCredentialsChanged:(id)object;
- (void)bookmarkUpdateFailedWithError:(NSError *)error;
- (void)bookmarkUpdateProducedNoChange;
- (void)bookmarkUpdateProducedNewBookmarks:(NSArray *)bookmarks forUser:(NSString *)username;
- (HGSObject *)makeResultForUrl: (NSString *)url
                          title:(NSString *)title
                           type:(NSString *)type
                           tags:(NSSet *)tags
                           icon:(NSImage*)iconImage;
@end

@implementation DeliciousBookmarksSource

- (id)initWithConfiguration:(NSDictionary *)configuration {
	if ((self = [super initWithConfiguration:configuration])) {
		NSBundle* sourceBundle = HGSGetPluginBundle();
		NSString *iconPath = [sourceBundle pathForImageResource:@"delicious"];
		tagIcon_ = [[NSImage alloc] initByReferencingFile:iconPath];
		id<HGSAccount> account
			= [configuration objectForKey:kHGSExtensionAccountIdentifier];
		accountIdentifier_ = [[account identifier] retain];
		if (accountIdentifier_) {
			// Get bookmarks now, and schedule a timer to update it every hour.
			[self startAsynchronousBookmarkFetch];
			[self setUpPeriodicRefresh];
			// Watch for credential changes.
			NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
			[nc addObserver:self
				   selector:@selector(loginCredentialsChanged:)
					   name:kHGSDidChangeAccountNotification
					 object:nil];
		} else {
			HGSLogDebug(@"Missing account identifier for DeliciousBookmarksSource '%@'",
						[self identifier]);
			[self release];
			self = nil;
		}
	}
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[deliciousClient_ release];
	if ([updateTimer_ isValid]) {
		[updateTimer_ invalidate];
	}
	[updateTimer_ release];
	[accountIdentifier_ release];
	[tagIcon_ release];
	
	[super dealloc];
}

#pragma mark -
#pragma mark Bookmarks Fetching

- (void)startAsynchronousBookmarkFetch {
	@synchronized(self) {
		// If we are still marked as fetching, something must have gone wrong with
		// the last update.  Try to clean it up
		if (deliciousClient_ && currentlyFetching_) {
			[deliciousClient_ cancelUpdate];
		}
		
		if (!deliciousClient_) {
			KeychainItem* keychainItem 
			= [KeychainItem keychainItemForService:accountIdentifier_
										  username:nil];
			if (!keychainItem ||
				[[keychainItem username] length] == 0 ||
				[[keychainItem password] length] == 0) {
				// Can't do much without a login; invalidate so we stop trying (until
				// we get a notification that the credentials have changed) and bail.
				[updateTimer_ invalidate];
				return;
			}
			deliciousClient_ = [[DeliciousClient alloc] initWithUsername:[keychainItem username]
																password:[keychainItem password]];
		}
		
		// Mark us as in the middle of a fetch so that if credentials change during
		// a fetch we don't destroy the service out from under ourselves.
		currentlyFetching_ = YES;
	}
	
	[deliciousClient_ returnUpdatedDataTo:self
					handleNewDataSelector:@selector(bookmarkUpdateProducedNewBookmarks:forUser:)
				   handleNoChangeSelector:@selector(bookmarkUpdateProducedNoChange)
					handleFailureSelector:@selector(bookmarkUpdateFailedWithError:)];
}

- (void)setUpPeriodicRefresh {
	// if we are already running the scheduled check, we are done.
	if ([updateTimer_ isValid])
		return;
	[updateTimer_ release];
	updateTimer_ = [[NSTimer scheduledTimerWithTimeInterval:(60 * 60)
													 target:self
												   selector:@selector(refreshBookmarks:)
												   userInfo:nil
													repeats:YES] retain];
}

- (void)refreshBookmarks:(NSTimer *)timer {
	[self startAsynchronousBookmarkFetch];
}

- (void)loginCredentialsChanged:(id)object {
	if ([accountIdentifier_ isEqualToString:object]) {
		@synchronized(self) {
			// Make sure we aren't in the middle of waiting for results; if we are, try
			// again later instead of changing things in the middle of the fetch.
			if (currentlyFetching_) {
				[self performSelector:@selector(loginCredentialsChanged:)
						   withObject:nil
						   afterDelay:60.0];
				return;
			}
			
			// Clear the client so that we make a new one with the correct credentials.
			[deliciousClient_ release];
			deliciousClient_ = nil;
		}

		// If the login changes, we should update immediately, and make sure the
		// periodic refresh is enabled (it would have been shut down if the previous
		// credentials were incorrect).
		[self startAsynchronousBookmarkFetch];
		[self setUpPeriodicRefresh];
	}
}

#pragma mark -
#pragma mark Bookmark indexing

- (void)bookmarkUpdateFailedWithError:(NSError *)error {
	@synchronized(self) {
		currentlyFetching_ = NO;
	}
	
	if ([error code] == 403) {
		// If the login credentials are bad, don't keep trying.
		[updateTimer_ invalidate];
	}
}

- (void)bookmarkUpdateProducedNoChange {
	@synchronized(self) {
		currentlyFetching_ = NO;
	}
}

- (void)bookmarkUpdateProducedNewBookmarks:(NSArray *)bookmarks forUser:(NSString *)username {
	@synchronized(self) {
		currentlyFetching_ = NO;
	}

	NSMutableSet *allTags = [NSMutableSet setWithCapacity:50];
	
	for (DeliciousBookmark *bookmark in bookmarks) {
		NSString *url = [bookmark url];
		NSString *title = [bookmark name];
		NSSet *tags = [bookmark tags];
		NSArray *tagArray = [tags allObjects];
		
		[allTags addObjectsFromArray:tagArray];
		
		HGSObject *result =
			[self makeResultForUrl: url
							 title: title
							  type: HGS_SUBTYPE(kHGSTypeWebBookmark, @"deliciousbookmarks")
							  tags: tags
							  icon:nil];
		
		[self indexResult:result
			   nameString:title
		otherStringsArray:tagArray];
	}
	
	for (NSString *tag in allTags) {
		NSString *url = [NSString stringWithFormat:@"http://delicious.com/%@/%@", username, tag];
		HGSObject *result =
			[self makeResultForUrl:url
							 title:tag
							  type:HGS_SUBTYPE(kHGSTypeWebpage, @"delicioustag")
							  tags: nil
							  icon:tagIcon_];
		[self indexResult:result nameString:tag otherString:nil];
	}
}

- (HGSObject *) makeResultForUrl: (NSString *)url
						   title:(NSString *)title
							type:(NSString *)type
							tags:(NSSet *)tags
							icon:(NSImage*)iconImage {
	NSNumber *rankFlags = [NSNumber numberWithUnsignedInt:eHGSUnderHomeRankFlag];
	NSMutableDictionary *attributes = [NSMutableDictionary dictionaryWithObjectsAndKeys:
									   rankFlags, kHGSObjectAttributeRankFlagsKey,
									   url, kHGSObjectAttributeSourceURLKey,
									   nil];
	if (tags) {
		[attributes setObject:tags forKey:kObjectAttributeDeliciousTags];
	}
	
	if (iconImage) {
		[attributes setObject:iconImage forKey:kHGSObjectAttributeIconKey];
	}

	HGSObject* result 
		= [HGSObject objectWithIdentifier:[NSURL URLWithString:url]
									 name:([title length] > 0 ? title : url)
									 type:type
								   source:self
							   attributes:attributes];
	return result;
}

- (void)processMatchingResults:(NSMutableArray*)results
                      forQuery:(HGSQuery *)query {
	// Pivot on tags, filter to only bookmarks with that tag
	HGSObject *pivotObject = [query pivotObject];
	if (pivotObject) {
		NSString *tag = [pivotObject displayName];
		NSMutableIndexSet *indexesToRemove = [NSMutableIndexSet indexSet];
		
		NSUInteger resultCount = [results count];
		for (NSUInteger idx = 0; idx < resultCount ; ++idx) {
			HGSObject *result = [results objectAtIndex:idx];
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

#pragma mark -
#pragma mark HGSAccountClientProtocol Methods

- (BOOL)accountWillBeRemoved:(id<HGSAccount>)account {
	BOOL removeMe = NO;
	NSString *accountIdentifier = [account identifier];
	if ([accountIdentifier_ isEqualToString:accountIdentifier]) {
		@synchronized(self) {
			if (currentlyFetching_) {
				[deliciousClient_ cancelUpdate];
			}
			[deliciousClient_ release];
			deliciousClient_ = nil;
		}
		removeMe = YES;
	}
	
	return removeMe;
}

@end

