#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBEditSimpleAccountWindowController.h>
#import <QSBPluginUI/QSBSetUpSimpleAccountViewController.h>

@interface DeliciousAccount : HGSSimpleAccount {
@private
	// Set by and only useful within authentication.
	BOOL authCompleted_;
	BOOL authSucceeded_;	
}
@end

@interface EditDeliciousAccountWindowController : QSBEditSimpleAccountWindowController
- (IBAction)openDeliciousHomePage:(id)sender;
@end

@interface SetUpDeliciousAccountViewController : QSBSetUpSimpleAccountViewController
- (IBAction)openDeliciousHomePage:(id)sender;
@end

