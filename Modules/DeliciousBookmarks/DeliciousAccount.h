#import <Vermilion/Vermilion.h>
#import <QSBPluginUI/QSBEditSimpleAccountWindowController.h>
#import <QSBPluginUI/QSBSetUpSimpleAccountViewController.h>

@interface DeliciousAccount : HGSSimpleAccount
@end

@interface EditDeliciousAccountWindowController : QSBEditSimpleAccountWindowController
- (IBAction)openDeliciousHomePage:(id)sender;
@end

@interface SetUpDeliciousAccountViewController : QSBSetUpSimpleAccountViewController
- (IBAction)openDeliciousHomePage:(id)sender;
@end

