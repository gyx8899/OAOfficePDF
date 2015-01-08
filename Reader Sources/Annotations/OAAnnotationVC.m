//
//  OAAnnotationVC.m
//  OAOffice
//
//  Created by admin on 14/12/8.
//  Copyright (c) 2014年 DigitalOcean. All rights reserved.
//

#import "OAAnnotationVC.h"
#import "DiscoveryPopoverViewController.h"

#define BATTERY_PERCENTAGE_SEGMENT 3

@interface OAAnnotationVC ()

@end

@implementation OAAnnotationVC
{
    IBOutlet UIButton *ConnectButton;
    DiscoveryPopoverViewController *mDiscoveredTable;
    UIPopoverController * mPopoverController;
    UIView *pageView;
}

- (id) initWithDocument:(ReaderDocument *)readerDocument
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
//        self.annotationType = AnnotationViewControllerType_None;
        self.document = readerDocument;
        
//        annotationColor = [UIColor redColor].CGColor;
//        signColor = [UIColor blackColor].CGColor;
//        eraseColor = [UIColor clearColor].CGColor;
        
        self.currentPage = 0;
//        image = [[UIImageView alloc] initWithImage:nil];
//        image.frame = CGRectMake(0,0,100,100); //so we don't error out
//        currentPaths = [NSMutableArray array];
        
//        annotationStore = [[AnnotationStore alloc] initWithPageCount:[readerDocument.pageCount intValue]];
    }
    return self;
}

- (void) moveToPage:(int)page contentView:(ReaderContentView*) view {
    if (page != self.currentPage || !pageView) {
//        [self finishCurrentAnnotation];
        
        self.currentPage = page;
//        pageView = [view contentView];
        pageView = (UIView *)view.theContentPage;
        
        //Create a new one because the old one may be deallocated or have a deallocated parent
        //First, erase any contents though
        
//        [self refreshDrawing];
        CGRect dvFrame = CGRectMake(0, 0, pageView.frame.size.width * view.zoomScale, pageView.frame.size.height * view.zoomScale);
        self.dV = [[drawingView alloc] initWithFrame:dvFrame];
        self.dV.center = CGPointMake(self.view.frame.size.width * 0.5, 10 + self.view.frame.size.height * 0.5);
        self.dV.backgroundColor = [UIColor clearColor];
        NSLog(@"%f,%@,%@,%@",view.zoomScale,NSStringFromCGRect(self.view.frame),NSStringFromCGRect(pageView.frame),NSStringFromCGRect(self.dV.frame));
        [self.view insertSubview:self.dV atIndex:0];
    }
}

- (void) clear{
    //Setting up a blank image to start from. This displays the current drawing
    [_dV erase];
}

- (void) hide {
    [self.view removeFromSuperview];
}

- (void) undo {
    
}


////////////////////////////////////////////////////////////////////////////////
// Function:showPopover
// Notes: registers for discovery related callbacks and sets up the window to show discovery
// status and results.
- (IBAction)showPopover:(UIView *)sender
{
    if(mDiscoveredTable == nil)
    {
        mDiscoveredTable = [[DiscoveryPopoverViewController alloc] init];
    }
    
    //allocates and sizes the window.
    if(!mPopoverController)
    {
        mPopoverController =  [[UIPopoverController alloc] initWithContentViewController:mDiscoveredTable];
        mPopoverController.popoverContentSize = CGSizeMake(280., 320.);
        mPopoverController.delegate = self;
    }
    
    // initiates discovery
    [[WacomManager getManager] startDeviceDiscovery];
    
    // shows the discovery popover.
    [mPopoverController presentPopoverFromRect:sender.frame inView:self.view permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
}


////////////////////////////////////////////////////////////////////////////////
// Function: viewDidLoad
// Notes: does basic setup of the demo app main screen
- (void)viewDidLoad
{
    [super viewDidLoad];
    [[WacomManager getManager] registerForNotifications:self];
    
    NSArray *segmentArray1 = [NSArray arrayWithObjects:NSLocalizedString(@"左手习惯",@"Left Hand"),NSLocalizedString(@"右手习惯",@"Right Hand"), nil];
    self.HandednessControl = [[UISegmentedControl alloc] initWithItems:segmentArray1];
    self.HandednessControl.frame = CGRectMake(40, 80, 200, 40);
    self.HandednessControl.selectedSegmentIndex = 1;
    self.HandednessControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin;
    [self.HandednessControl addTarget:self action:@selector(SegControlSetHandedness:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.HandednessControl];
    
    NSArray *segmentArray2 = [NSArray arrayWithObjects:NSLocalizedString(@"笔", @"pen"),NSLocalizedString(@"清除", @"clear"),NSLocalizedString(@"触摸开关",@"touch"),NSLocalizedString(@"电量", @""),NSLocalizedString(@"保存", @"save"), nil];
    self.toolBar = [[UISegmentedControl alloc] initWithItems:segmentArray2];
    self.toolBar.frame = CGRectMake(0, 80, 300, 40);
    self.toolBar.center = CGPointMake(self.view.frame.size.width * 0.5, 100);
    self.toolBar.selectedSegmentIndex = 3;
    self.toolBar.momentary = YES;
    self.toolBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth;
    [self.toolBar addTarget:self action:@selector(SegControlPerformAction:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:self.toolBar];
    
    [_toolBar setTitle:@"" forSegmentAtIndex:BATTERY_PERCENTAGE_SEGMENT];
    [_versionLabel setText:[[WacomManager getManager] getSDKVersion]];
    [[TouchManager GetTouchManager] setHandedness:eh_Right];
    [[TouchManager GetTouchManager] setTimingOffset:55000];
}


////////////////////////////////////////////////////////////////////////////////
// Function: didReceiveMemoryWarning
// Notes: calls the super did receive memory warning and does basically nothing else.
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}



////////////////////////////////////////////////////////////////////////////////
// Function: dealloc
// Notes: clears out all the allocations that have been made.
- (void)dealloc {
    [[WacomManager getManager] deregisterForNotifications:self];
    
}



////////////////////////////////////////////////////////////////////////////////
// Function: toggleTouchRejection
// Notes: enables or disables touch rejection based on the previous state.
-(void) toggleTouchRejection
{
    NSString *message   = nil;
    NSString *title     = NSLocalizedString(@"触感屏蔽", @"Touch Rejection");
    
    if([TouchManager GetTouchManager].touchRejectionEnabled == YES)
    {
        [TouchManager GetTouchManager].touchRejectionEnabled = NO;
    }
    else
    {
        [TouchManager GetTouchManager].touchRejectionEnabled = YES;
    }
    
    if([TouchManager GetTouchManager].touchRejectionEnabled == YES)
        message = NSLocalizedString(@"您已打开触感屏蔽", @"You have turned ON touch rejection.");
    else
        message = NSLocalizedString(@"您已关闭触感屏蔽", @"You have turned OFF touch rejection.");
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
    
}



////////////////////////////////////////////////////////////////////////////////
// Function: toggleTouchRejection
// Notes: enables or disables touch rejection based on the previous state.
-(IBAction)showPrivacyMessage:(UIButton *)sender
{
    NSString *message   = nil;
    NSString *title     = @"Privacy Info";
    
    message = @"This app does not collect information about its users. Only previous pairings are stored and they are stored locally. This app does not phone home.";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
    
}




////////////////////////////////////////////////////////////////////////////////
// Function: SegControlSetHandedness
// Notes: controls pairing, toggles touch rejection, and erases the screen when the
// segmented control is clicked.
- (IBAction)SegControlSetHandedness:(UISegmentedControl *)sender
{
    
    switch(sender.selectedSegmentIndex)
    {
        case 0:
            // Initiates the pairing mode popover.
            [[TouchManager GetTouchManager] setHandedness:eh_Left];
            break;
        case 1:
            // Clears the screen
            [[TouchManager GetTouchManager] setHandedness:eh_Right];
            break;
        default:
            break;
    };
    
}




////////////////////////////////////////////////////////////////////////////////
// Function: SegControlPerformAction
// Notes: controls pairing, toggles touch rejection, and erases the screen when the
// segmented control is clicked.
- (IBAction)SegControlPerformAction:(UISegmentedControl *)sender
{
    
    switch(sender.selectedSegmentIndex)
    {
        case 0:
            // Initiates the pairing mode popover.
            [self showPopover:sender];
            break;
        case 1:
            // Clears the screen
            [_dV erase];
            break;
        case 2:
            // Toggles touch rejection on and off.
            [self toggleTouchRejection];
            break;
        case 4:
            // Save Image
            [self saveImage:[_dV glToUIImage]];
            break;
        default:
            break;
    };
    
}

- (void)saveImage:(UIImage *)image
{
    NSData *pngData = UIImagePNGRepresentation(image);
    // Only save the first page annotation image(png)
    if (self.currentPage <= 1) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath = [paths objectAtIndex:0]; //Get the docs directory
//        NSDictionary *taskInfoDic = [NSJSONSerialization JSONObjectWithData:_document.taskInfo options:NSJSONReadingMutableLeaves error:nil];
        NSString *signPngName = [NSString stringWithFormat:@"%@.png",_document.fileId];
        NSString *filePath = [documentsPath stringByAppendingPathComponent:signPngName]; //Add the file name
        [pngData writeToFile:filePath atomically:YES]; //Write the file
    }
}


////////////////////////////////////////////////////////////////////////////////
// Function:deviceDiscovered
// Notes: just add the device to the discovered table. demonstrates signal strength
-(void) deviceDiscovered:(WacomDevice *)device
{
    //	NSLog(@"signal strength %i", [device getSignalStrength]);
    [mDiscoveredTable addDevice:device];
}



////////////////////////////////////////////////////////////////////////////////
// Function:deviceConnected
// Notes: update the device table then dismiss the popover.
-(void) deviceConnected:(WacomDevice *)device
{
    [mDiscoveredTable updateDevices:device];
}



////////////////////////////////////////////////////////////////////////////////
// Function:deviceDisconnected
// Notes: remove the device then dismiss the popover
-(void)deviceDisconnected:(WacomDevice *)device
{
    [mDiscoveredTable removeDevice:device];
    [_toolBar setTitle:@"" forSegmentAtIndex:BATTERY_PERCENTAGE_SEGMENT];
    
}



////////////////////////////////////////////////////////////////////////////////
// Function: discoveryStatePoweredOff
// Notes: if the power is off, it pops a warning dialog.
-(void)discoveryStatePoweredOff
{
    NSString *title     = NSLocalizedString(@"蓝牙开关", @"Bluetooth Power");//@"Bluetooth Power"
    NSString *message   = NSLocalizedString(@"请在设置中打开蓝牙", @"You must turn on Bluetooth in Settings");//@"You must turn on Bluetooth in Settings";
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"好的", @"OK") otherButtonTitles:nil];
    [alertView show];
}



////////////////////////////////////////////////////////////////////////////////
// Function:stylusEvent
// Notes: update the battery status segment in the tool bar.
-(void)stylusEvent:(WacomStylusEvent *)stylusEvent
{
    switch ([stylusEvent getType])
    {
        case eStylusEventType_BatteryLevelChanged:
            [_toolBar setTitle:[NSString stringWithFormat:@"%lu%%", [stylusEvent getBatteryLevel] ] forSegmentAtIndex:BATTERY_PERCENTAGE_SEGMENT];
        default:
            break;
    }
}

@end
