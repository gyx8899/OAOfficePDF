/*!--------------------------------------------------------------------------------------------------

 FILE NAME

 DisoveryPopoverViewController.h

 Abstract: header file for the discovery popover controller


 COPYRIGHT
 Copyright WACOM Technology, Inc. 2012-2014
 All rights reserved.

 --------------------––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––––-––-----*/


#import <UIKit/UIKit.h>
#import <WacomDevice/WacomDeviceFramework.h>
@interface DiscoveryPopoverViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
{
		IBOutlet UIView *popoverview;
}
/// adds a device to the table in the popover
-(void) addDevice:(WacomDevice *)device;

/// removes a device from the table in the popover
-(void) removeDevice:(WacomDevice *)device;

/// adds a device int the discovery popover if it is not there already
-(void)updateDevices:(WacomDevice *)device;
@end
