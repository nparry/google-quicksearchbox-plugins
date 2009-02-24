#import <Vermilion/Vermilion.h>
#import "GTMLargeTypeWindow.h"

@interface Rot13Action : HGSAction
@end

@implementation Rot13Action

- (BOOL)performActionWithInfo:(NSDictionary*)info {
	HGSObject *object = [info objectForKey:kHGSActionPrimaryObjectKey];
	BOOL success = NO;
	if (object) {
		NSString *text = [object displayName];
		size_t length = [text length];
		
		unichar *buffer = malloc(length*sizeof(unichar));
		[text getCharacters:buffer];
		
		for (int i = 0; i < length; i++) {
			unichar c = buffer[i];
			buffer[i] = isalpha(c)?tolower(c)<'n'?c+13:c-13:c;
		}
		
		NSString *rot13ified = [NSString stringWithCharacters:buffer length:length];
		free(buffer);
		
		GTMLargeTypeWindow *largeTypeWindow
		= [[GTMLargeTypeWindow alloc] initWithString:rot13ified];
		[largeTypeWindow setReleasedWhenClosed:YES];
		[largeTypeWindow makeKeyAndOrderFront:self];
		success = YES;
	}
	return success;
}
@end
