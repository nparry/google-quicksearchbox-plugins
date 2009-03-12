#import <Vermilion/Vermilion.h>
#import <CoreServices/CoreServices.h>

// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
//
// QSB now ships with a built-in action to do this, so this
// class is deprecated.  I have left it around for reference,
// but it is removed from the XCode project for these plugins.
//
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
// !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

// An action that will delete a file.
//
@interface MoveToTrashAction : HGSAction

- (BOOL)moveToTrash:(NSURL *)filePath;

@end


@implementation MoveToTrashAction

- (id)initWithConfiguration:(NSDictionary *)configuration {
  if ((self = [super initWithConfiguration:configuration])) {
    // todo - set up a nice trash icon?
  }
  return self;
}

- (void)dealloc {
  [super dealloc];
}

- (BOOL)performActionWithInfo:(NSDictionary*)info {
  HGSResultArray *objects = [info valueForKey:kHGSActionDirectObjectsKey];
  BOOL success = YES;
  if (objects) {
	  NSArray *urls = [objects urls];
	  for (NSURL *url in urls) {
		  HGSLogDebug(@"Trying to trash: '%@'", url);
		  BOOL singleSuccess = [self moveToTrash:url];
		  success = success && singleSuccess;
	  }
  }
  return success;
}

- (BOOL)moveToTrash:(NSURL *)filePath {
	if (!filePath) {
		return NO;
	}
	
	if (![filePath isFileURL]) {
		HGSLogDebug(@"Not a file URL: '%@'", filePath);
		return NO;
	}

	FSRef fsref;
	BOOL success = CFURLGetFSRef((CFURLRef)filePath, &fsref);
	if (success) {
		OSStatus status = FSMoveObjectToTrashSync(&fsref, NULL, kFSFileOperationDefaultOptions);
		if (status == noErr) {
			success = YES;
		}
	}

	return success;
}

@end
