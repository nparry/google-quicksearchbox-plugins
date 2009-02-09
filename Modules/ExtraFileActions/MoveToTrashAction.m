#import <Vermilion/Vermilion.h>
#import <CoreServices/CoreServices.h>

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
  HGSObject *object = [info valueForKey:kHGSActionPrimaryObjectKey];
  BOOL success = NO;
  if (object) {
    NSURL *url = [object identifier];
	HGSLogDebug(@"Trying to trash: '%@'", url);
    success = [self moveToTrash:url];
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
