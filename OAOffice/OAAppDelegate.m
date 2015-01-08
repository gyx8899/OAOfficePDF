//
//  OAAppDelegate.m
//  OAOffice
//
//  Created by admin on 14-7-24.
//  Copyright (c) 2014年 DigitalOcean. All rights reserved.
//

#import "OAAppDelegate.h"
#import <LocalAuthentication/LocalAuthentication.h>

#import "OALoginViewController.h"
#import "OAMasterViewController.h"
#import "OADetailViewController.h"
#import "AFNetworking.h"
#import "OACrashLog.h"

@implementation OAAppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize locationManager = _locationManager;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setStatusBarStyle:UIStatusBarStyleLightContent];
    // 1.初始化位置定位，并开始定位
    [self initCoreLocation];
    // 2.初始化网络状态监听
    [self initNetworkMonitor];
    // 3.Crash日志记录并上传
    [OACrashLog LogInit];
    // 4.初始化日志Plist
    [self initPlistFile];
    
    UISplitViewController *splitViewController = (UISplitViewController *)self.window.rootViewController;
    UINavigationController *navigationController = [splitViewController.viewControllers lastObject];
    splitViewController.delegate = (id)navigationController.topViewController;
    
    UINavigationController *masterNavigationController = splitViewController.viewControllers[0];
    OAMasterViewController *masterController = (OAMasterViewController *)masterNavigationController.topViewController;
    masterController.managedObjectContext = self.managedObjectContext;
    
    UINavigationController *detailNavigationController = splitViewController.viewControllers[1];
    OADetailViewController *detailController = (OADetailViewController *)detailNavigationController.topViewController;
    detailController.managedObjectContext = self.managedObjectContext;
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    if ([CLLocationManager significantLocationChangeMonitoringAvailable])
    {
        // Stop normal location updates and start significant location change updates for battery efficiency.
//        [_locationManager startUpdatingLocation];
    }
    else
    {
        NSLog(@"Significant location change monitoring is not available.");
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    if ([CLLocationManager significantLocationChangeMonitoringAvailable])
    {
        // Stop significant location updates and start normal location updates again since the app is in the forefront.
//        [_locationManager startUpdatingLocation];
//        [_locationManager stopUpdatingLocation];
    }
    else
    {
        NSLog(@"Significant location change monitoring is not available.");
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}

- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification*)notification{
//    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"本地推送,下载完成！" message:notification.alertBody delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
//    [alert show];
//    [self showAlertTitle:@"您有新的公文需要批阅" message:notification.alertBody];
    // 图标上的数字减1
//    application.applicationIconBadgeNumber -= 1;
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"OAOffice" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"OAOffice.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }    
    
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - CoreLocation
- (void)initCoreLocation
{
    _locationManager = [[CLLocationManager alloc] init];//创建位置管理器
    
    _locationManager.delegate = self;
    
    _locationManager.desiredAccuracy = kCLLocationAccuracyThreeKilometers;//kCLLocationAccuracyBest;
    
    _locationManager.distanceFilter = 1000000.0f;
    
    // 判断是否 iOS 8
    if([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestAlwaysAuthorization]; // 永久授权
        [self.locationManager requestWhenInUseAuthorization]; //使用中授权
    }
    [self.locationManager startUpdatingLocation];
}

- (void)initNetworkMonitor
{
//    NSURL *baseURL = [NSURL URLWithString:@"http://www.baidu.com/"];
    NSURL *baseURL = [NSURL URLWithString:kBaseURL];
    AFHTTPRequestOperationManager *manager = [[AFHTTPRequestOperationManager alloc] initWithBaseURL:baseURL];
    NSOperationQueue *operationQueue = manager.operationQueue;
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        NSLog(@"Reachability: %@", AFStringFromNetworkReachabilityStatus(status));
        static AFNetworkReachabilityStatus lastStatus = 2;
        switch (status) {
            case AFNetworkReachabilityStatusReachableViaWWAN:
            case AFNetworkReachabilityStatusReachableViaWiFi:
            {
                [operationQueue setSuspended:NO];
                
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                [userDefaults setObject:@"OK" forKey:kNetConnect];
                [userDefaults synchronize];
                
                if (lastStatus == -1 || lastStatus == 0) {
                    [self showAlertTitle:@"提醒：" message:@"当前网络已连接，网络状态良好！"];
                }
                break;
            }
            case AFNetworkReachabilityStatusNotReachable:
            default:
            {
                [operationQueue setSuspended:YES];
                
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                [userDefaults setObject:@"Error" forKey:kNetConnect];
                [userDefaults synchronize];
                
                if (lastStatus == 1 || lastStatus == 2) {
                    [self showAlertTitle:@"提醒：" message:@"当前网络不可用,请请稍后重试！"];
                }
                break;
            }
        }
        lastStatus = status;
    }];
}

- (void)initPlistFile
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *plistPath = [documentsDirectory stringByAppendingPathComponent:@"Log.plist"];
    NSString *userPlist = [documentsDirectory stringByAppendingPathComponent:@"UserGroup.plist"];
    NSString *userInfo  = [documentsDirectory stringByAppendingPathComponent:@"UserInfo.plist"];
    
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    [userDefaults setObject:plistPath forKey:kPlistPath];
    [userDefaults setObject:userPlist forKey:kUserPlist];
    [userDefaults setObject:userInfo  forKey:kInfoPlist];
    
    NSString *deviceInfo = [NSString stringWithFormat:@"%@,%@,%@,%@",[[UIDevice currentDevice] name],[[UIDevice currentDevice] model],[[UIDevice currentDevice] systemName],[[UIDevice currentDevice] systemVersion]];
    [userDefaults setObject:deviceInfo forKey:kDeviceInfo];
    [userDefaults synchronize];
}

#pragma mark - UIAlertView with timer
- (void)timerFireMethod:(NSTimer*)theTimer
{
    UIAlertView *promptAlert = (UIAlertView *)[theTimer userInfo];
    [promptAlert dismissWithClickedButtonIndex:0 animated:NO];
    promptAlert = NULL;
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)message
{
    UIAlertView *promptAlert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [NSTimer scheduledTimerWithTimeInterval:2.5f
                                     target:self
                                   selector:@selector(timerFireMethod:)
                                   userInfo:promptAlert
                                    repeats:YES];
    [promptAlert show];
}

@end
