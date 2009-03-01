#import <Vermilion/Vermilion.h>
#import <QuartzCore/QuartzCore.h>
#import "GTMLargeTypeWindow.h"

static const CGFloat kTwoThirdsAlpha = 0.66;
static const int kFontSize = 16;

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
		
		// Copy this from the easy large type window initWithString so we can control
		// the font size.
		NSMutableAttributedString *attrString
			= [[[NSMutableAttributedString alloc] initWithString:rot13ified] autorelease];
		
		NSRange fullRange = NSMakeRange(0, [rot13ified length]);
		[attrString addAttribute:NSForegroundColorAttributeName 
						   value:[NSColor whiteColor] 
						   range:fullRange];
		
		NSMutableParagraphStyle *style 
			= [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[style setAlignment:NSCenterTextAlignment];
		[attrString addAttribute:NSParagraphStyleAttributeName 
						   value:style 
						   range:fullRange];
		
		NSShadow *textShadow = [[[NSShadow alloc] init] autorelease];
		[textShadow setShadowOffset:NSMakeSize( 5, -5 )];
		[textShadow setShadowBlurRadius:10];
		[textShadow setShadowColor:[NSColor colorWithCalibratedWhite:0 
															   alpha:kTwoThirdsAlpha]];
		[attrString addAttribute:NSShadowAttributeName 
						   value:textShadow 
						   range:fullRange];
		
		NSFont *font = [NSFont boldSystemFontOfSize:kFontSize] ;
		[attrString addAttribute:NSFontAttributeName 
						   value:font
						   range:fullRange];
		
		GTMLargeTypeWindow *largeTypeWindow
		= [[GTMLargeTypeWindow alloc] initWithAttributedString:attrString];
		[largeTypeWindow setReleasedWhenClosed:YES];
		[largeTypeWindow makeKeyAndOrderFront:self];
		success = YES;
	}
	return success;
}
@end
