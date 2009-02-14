#import <Foundation/Foundation.h>

@interface DeliciousBookmark : NSObject {
	NSString *name;
	NSString *url;
	NSSet *tags;
}
-(id)initWithName:(NSString *)aName
			  url:(NSString *)aUrl
			 tags:(NSArray *)theTags;
@property (readonly) NSString* name;
@property (readonly) NSString* url;
@property (readonly) NSSet* tags;
@end
 

@interface DeliciousClient : NSObject {
	NSString *username_;
	NSString *password_;
	NSString *lastUpdate_;
	
	NSURLConnection *connection_;
	NSMutableData *dataBuffer_;
	SEL connectionCompleteCallbackSelector_;
	
	id delegate_;
	SEL newDataSelector_;
	SEL noChangeSelector_;
	SEL failureSelector_;
}
- (id)initWithUsername:(NSString *)username
			  password:(NSString *) password;
- (void) returnUpdatedDataTo:(id)delegate
	   handleNewDataSelector:(SEL)newDataSelector
	  handleNoChangeSelector:(SEL)noChangeSelector
	   handleFailureSelector:(SEL)failureSelector;
- (void) cancelUpdate;
@end
