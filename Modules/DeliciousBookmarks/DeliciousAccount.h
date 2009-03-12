#import <Vermilion/Vermilion.h>

@interface DeliciousAccount : HGSSimpleAccount
@end

@interface DeliciousAccountEditController : HGSSimpleAccountEditController
- (IBAction)goToDelicious:(id)sender;
@end

@interface SetUpDeliciousAccountViewController : HGSSetUpSimpleAccountViewController
- (IBAction)goToDelicious:(id)sender;
@end

