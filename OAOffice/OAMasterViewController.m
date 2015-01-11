//
//  OAMasterViewController.m
//  OAOffice
//
//  Created by admin on 14-7-24.
//  Copyright (c) 2014年 DigitalOcean. All rights reserved.
//

#import "OAMasterViewController.h"
#import "OADetailViewController.h"
#import "OALoginViewController.h"
#import "DoneMissive.h"
#import "OADoneMissiveCell.h"
#import "INSSearchBar.h"
#import "OASearchBarVC.h"
#import "OACover.h"
#import "MJRefresh.h"

@interface OAMasterViewController ()<RefreashMasterDoneMission,UIAlertViewDelegate,INSSearchBarDelegate,SearchBarToMasterDelegate>
{
    INSSearchBar *_searchBar;
    NSString *_userName;
    OASearchBarVC *_searchResult;
    OACover *_cover;
    
    NSMutableArray *_dataSource;// 公文数据源
}
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
@end

@implementation OAMasterViewController

- (void)awakeFromNib
{
    self.clearsSelectionOnViewWillAppear = NO;
    self.preferredContentSize = CGSizeMake(320.0, 600.0);
    [super awakeFromNib];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.detailViewController = (OADetailViewController *)[[self.splitViewController.viewControllers lastObject] topViewController];
    self.masterToDeatilDelegate = (id)self.detailViewController;
    
    [self initNaviColor];
    [self initNaviTitle];
    [self initExitBar];
    [self initSearchBar];
    
    [self addHeader];
    [self addFooter];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)insertNewObject:(id)sender
{
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
    NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
    
    // If appropriate, configure the new managed object.
    // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
    [newManagedObject setValue:[NSDate date] forKey:@"timeStamp"];
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
         // Replace this implementation with code to handle the error appropriately.
         // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}

#pragma mark - Init Methods
- (void)initNaviColor
{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.navigationController.navigationBar.barTintColor = kThemeColor;
    self.navigationController.toolbar.barTintColor = kThemeColor;
    self.navigationController.view.tintColor = UIColor.whiteColor;
}

- (void)initNaviTitle
{
    _userName = [[NSUserDefaults standardUserDefaults] objectForKey:kName];
    [self refreashMasterTitleWithName:_userName];
}

- (void)initExitAlert
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"您确认退出？" message:@"" delegate:self cancelButtonTitle:@"确认" otherButtonTitles:@"取消", nil];
    [alert show];
}

- (void)initSearchBar
{
    _searchBar = [[INSSearchBar alloc] initWithFrame:CGRectMake(0, 0, 38, 38.0)];
    _searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    _searchBar.delegate = self;
    UIBarButtonItem *searchBar = [[UIBarButtonItem alloc] initWithCustomView:_searchBar];
    self.navigationItem.rightBarButtonItem = searchBar;
}

- (void)initExitBar
{
    UIBarButtonItem *exitButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"User-Exit.png"] style:UIBarButtonItemStyleDone target:self action:@selector(initExitAlert)];
    self.navigationItem.leftBarButtonItem = exitButton;
}

#pragma mark Refreash TableView
- (void)addHeader
{
    __unsafe_unretained typeof(self) vc = self;
    // 添加下拉刷新头部控件
    [self.tableView addHeaderWithCallback:^{
        // 进入刷新状态就会回调这个Block
        [vc refreashTableViewWithPageSize:kPageSize pageNum:1];
        
        [vc.tableView reloadData];
        // 结束刷新
        [vc.tableView headerEndRefreshing];
    } dateKey:@"tableview"];
    // dateKey用于存储刷新时间，也可以不传值，可以保证不同界面拥有不同的刷新时间
}

- (void)addFooter
{
    __unsafe_unretained typeof(self) vc = self;
    // 添加上拉刷新尾部控件
    [self.tableView addFooterWithCallback:^{
        // 进入刷新状态就会回调这个Block
        [vc refreashTableViewWithPageSize:kPageSize pageNum:((int)[vc.tableView numberOfRowsInSection:0]/kPageSize+1)];
        
        [vc.tableView reloadData];
        // 结束刷新
        [vc.tableView footerEndRefreshing];
    }];
}

- (void)refreashTableViewWithPageSize:(int)pageSize pageNum:(int)pageNum
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *userName = [userDefaults objectForKey:kUserName];
    NSString *netConnect = [userDefaults objectForKey:kNetConnect];
    __block NSString *authorizationHeader = [userDefaults objectForKey:kAuthorizationHeader];
    // 用户名和密码非空和网络OK时，获取最新任务列表
    if (userName && [netConnect isEqualToString:@"OK"] && authorizationHeader) {
        NSString *serverURL = [[NSString stringWithFormat:@"%@api/ipad/getDoneMissive/%@/%d/%d",kBaseURL,userName,pageSize,pageNum] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];//转码成UTF-8  否则可能会出现错
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        [manager.requestSerializer setValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
        [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"content-type"];
        manager.responseSerializer = [AFJSONResponseSerializer serializer];
        
        [manager GET:serverURL parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            if (responseObject == nil) {
                return ;
            }
            // 3 解析返回的JSON数据
            NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseObject options:NSJSONWritingPrettyPrinted error:nil];
            NSArray *result = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:nil];
            for (NSDictionary *dic in result) {
                [self insertNewDoneMissionWithObject:dic];
            }
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSString *info = [NSString stringWithFormat:@"Error:刷新最历史公文失败错误.%@",error.description];
            [OATools newLogWithInfo:info time:[NSDate date] type:kLogErrorType];
        }];
    }
}

#pragma mark - Table View

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 66;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
//    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    static NSString *cellIdentifier = @"OADoneMissiveCell";
    OADoneMissiveCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        NSArray *nib = [[NSBundle mainBundle]loadNibNamed:@"OADoneMissiveCell" owner:self options:nil];
        if ([[nib objectAtIndex:0] isKindOfClass:[OADoneMissiveCell class]]) {
            cell = [nib objectAtIndex:0];
        }
    }
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (0 == section) {
        UIView *view = [[UIView alloc]initWithFrame:CGRectMake(0, 0, tableView.frame.size.width, 20)];
        UILabel *headTitle = [[UILabel alloc] initWithFrame:CGRectMake(15, 0, 200, 20)];
        headTitle.text = @"您的已办公文";
        [view addSubview:headTitle];
        return view;
    }else{
        return nil;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 20;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    self.detailViewController.detailItem = object;
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"DoneMissive" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:50];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"missiveDoneTime" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"用户名"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}    

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
        default:
            ;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}
 */

- (void)configureCell:(OADoneMissiveCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.missiveTitle.text = [object valueForKey:kMissiveTitle];
    cell.missiveTaskName.text = [object valueForKey:kTaskName];
    cell.missiveAddr = [object valueForKey:kMissiveAddr];
    
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
    cell.missiveDoneTime.text = [dateFormatter stringFromDate:[object valueForKey:kMissiveDoneTime]];
    
    NSString *type = [cell.missiveAddr componentsSeparatedByString:@"/"][2];
    cell.missiveType.clipsToBounds = YES;
    cell.missiveType.layer.cornerRadius = 5;
    if ([type isEqualToString:@"missivePublish"]) {
        cell.missiveType.text = @"发文";
    }else if ([type isEqualToString:@"missiveReceive"]){
        cell.missiveType.text = @"收文";
    }else if ([type isEqualToString:@"missiveSign"]){
        cell.missiveType.text = @"签报";
    }else if ([type isEqualToString:@"faxCablePublish"]){
        cell.missiveType.text = @"传真电报";
    }
    [cell.missiveDownloadBtn addTarget:self action:@selector(cellMissiveFileDownload:) forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark - Other Methods
- (BOOL)searchWithPredicate:(NSString *)predicate
{
    // 1. 实例化查询请求
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:kOADoneMissive];
    
    // 2. 设置谓词条件
    request.predicate = [NSPredicate predicateWithFormat:predicate];
    
    // 3. 由上下文查询数据
    NSArray *result = [self.managedObjectContext executeFetchRequest:request error:nil];
//    NSUInteger count = [self.managedObjectContext countForFetchRequest:request error:nil];

    if ([result count] > 0) {
        return YES;
    }else{
        return NO;
    }
}

- (void)cellMissiveFileDownload:(UIButton *)sender
{
    NSIndexPath *indexPath = [self.tableView indexPathForCell:(OADoneMissiveCell *)sender.superview.superview];
    NSManagedObject *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
    [self.masterToDeatilDelegate downloadDoneMissiveWithObject:object];
}

#pragma mark - SearchBarToMasterDelegate
- (void)sendSearchBarResultWithDic:(NSDictionary *)result
{
    [self.masterToDeatilDelegate downloadDoneMissiveWithObject:result];
}

#pragma mark - UIAlertView Delegate 右顶角按钮提示
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0: // 确认
        {
            // 跳转到登录界面；
            [self.masterToDeatilDelegate exitToLoginVC];
        }
            break;
        case 1: // 取消
            break;
        default:
            break;
    }
}

#pragma mark - OAMasterDelegate
- (void)insertNewDoneMissionWithObject:(NSDictionary *)object
{
    NSString *taskId = [NSString stringWithFormat:@"%@",[object objectForKey:kTaskId]];
    NSString *predicate = [NSString stringWithFormat:@"taskId = '%@'",taskId];
    
    if (![self searchWithPredicate:predicate]) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
        
        // If appropriate, configure the new managed object.
        // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
        
        [newManagedObject setValue:taskId forKey:kTaskId];
        [newManagedObject setValue:[object objectForKey:kTaskName] forKey:kTaskName];
        [newManagedObject setValue:[object objectForKey:kMissiveTitle] forKey:kMissiveTitle];
        [newManagedObject setValue:[object objectForKey:kMissiveAddr] forKey:kMissiveAddr];
        [newManagedObject setValue:[object objectForKey:@"urgency"] forKey:kUrgentLevel];
        
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSDate *missiveDoneTime = [dateFormatter dateFromString:[object valueForKey:kMissiveDoneTime]];
        [newManagedObject setValue:missiveDoneTime forKey:kMissiveDoneTime];
        
        
        // Save the context.
        NSError *error = nil;
        if (![context save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (void)refreashMasterTitleWithName:(NSString *)name
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:20.0];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor whiteColor]; // change this color
    label.text = NSLocalizedString(name, @"title");
    [label sizeToFit];
    _userName = name;
    self.navigationItem.titleView = label;
}

#pragma mark - search bar delegate

- (CGRect)destinationFrameForSearchBar:(INSSearchBar *)searchBar
{
    [searchBar.searchField setFrame:CGRectMake(15, 4.0, self.tableView.frame.size.width - 15 - 34, 28)];
    return CGRectMake(6.0, 20, CGRectGetWidth(self.tableView.bounds) - 40.0, 34.0);
//    return CGRectMake(66.0, 20, CGRectGetWidth(self.tableView.bounds) - 100.0, 34.0);
}

- (void)searchBar:(INSSearchBar *)searchBar willStartTransitioningToState:(INSSearchBarState)destinationState
{
    if (destinationState == 1) {
        [self refreashMasterTitleWithName:@""];
        self.navigationItem.leftBarButtonItem = nil;
        // 1.显示取消按钮
//        [_searchBar setShowsCancelButton:YES animated:YES];
        
        // 2.显示遮盖（蒙板）
        if (_cover == nil) {
            _cover = [OACover coverWithTarget:self action:@selector(coverClick)];
        }
        _cover.frame = self.tableView.frame;
        [self.view addSubview:_cover];
        _cover.alpha = 0.0;
        [UIView animateWithDuration:0.3 animations:^{
            [_cover reset];
        }];
    }else{
        [self coverClick];
        [self initExitBar];
        [self initNaviTitle];
    }
}

- (void)searchBar:(INSSearchBar *)searchBar didEndTransitioningFromState:(INSSearchBarState)previousState
{
    if(previousState != INSSearchBarStateNormal){
        
    }
}

- (void)searchBarDidTapReturn:(INSSearchBar *)searchBar
{
    if (searchBar.searchField.text.length > 0) {
        [self.masterToSearchDelegate searchWithText:searchBar.searchField.text];
    }
}

- (void)searchBarTextDidChange:(INSSearchBar *)searchBar
{
    if (searchBar.searchField.text.length == 0) {
        // 隐藏搜索界面
        [_searchResult.view removeFromSuperview];
    } else {
        // 显示搜索界面
        if (_searchResult == nil) {
            _searchResult = [[OASearchBarVC alloc] init];
            _searchResult.view.frame = _cover.frame;
            _searchResult.searchBarDelegate = self;
            _searchResult.view.autoresizingMask = _cover.autoresizingMask;
            [self addChildViewController:_searchResult];
            self.masterToSearchDelegate = (id)_searchResult;
        }
//        _searchResult.searchText = searchText;
        [self.view addSubview:_searchResult.view];
    }
}

#pragma mark 监听点击遮盖
- (void)coverClick
{
    // 1.移除遮盖
    [UIView animateWithDuration:0.3 animations:^{
        _cover.alpha = 0.0;
    } completion:^(BOOL finished) {
        [_cover removeFromSuperview];
    }];
    
    // 2.隐藏取消按钮
//    [_searchBar setShowsCancelButton:NO animated:YES];
    
    // 3.退出键盘
    [_searchBar resignFirstResponder];
}

@end
