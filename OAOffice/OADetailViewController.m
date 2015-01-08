//
//  OADetailViewController.m
//  OAOffice
//
//  Created by admin on 14-7-24.
//  Copyright (c) 2014年 DigitalOcean. All rights reserved.
//

#import "OAAppDelegate.h"
#import "OADetailViewController.h"
#import "OAMasterViewController.h"
#import "OALoginViewController.h"
#import "ReaderViewController.h"

#import "OAPDFCell.h"
#import "OAPDFHeader.h"
#import "OAPDFFlowLayout.h"

#import "MJRefresh.h"
#import "CoreDataManager.h"
#import "ReaderDocument.h"
#import "DoneMissive.h"
#import "AFNetworking.h"

@interface OADetailViewController () <UIPopoverControllerDelegate, UIAlertViewDelegate, ReaderViewControllerDelegate, OALoginViewControllerDelegate, MasterToDetailDelegate>
{
    BOOL shouldReloadCollectionView;
    NSBlockOperation *blockOperation;
    
    ReaderDocument  *_openedDocument;
    ReaderDocument  *_deletedDocument;
    NSIndexPath     *_selectedIndexPath;
    
    NSNumber        *_editState;
    
    NSDictionary    *_itemDic;
    
    UILabel         *_noItemsLabel;
    
    NSTimeInterval  _timeExpiredFile;
    
    NSMutableArray  *_objectChanges;
    NSMutableArray  *_sectionChanges;
}

// Non-UI Properties

@property (strong, nonatomic) UIPopoverController *masterPopoverController;
- (void)configureView;
@end

@implementation OADetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(id)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
    }

    if (self.masterPopoverController != nil) {
        [self.masterPopoverController dismissPopoverAnimated:YES];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self.detailItem) {
//        self.detailDescriptionLabel.text = [[self.detailItem valueForKey:@"timeStamp"] description];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // 1.初始化界面
    [self configureView];
    
    [self initNaviTitle];
    [self initNaviColor];
    [self initRightBtn];
//    [self initNoItemLabel];
    
    
    // 2. Init var
    _objectChanges = [NSMutableArray array];
    _sectionChanges = [NSMutableArray array];
    
    _timeExpiredFile = 60;//初始化为60s
    _openedDocument  = nil;
    _deletedDocument = nil;
    
    _editState = @1;//初始化为1，表示非编辑状态
    _selectedIndexPath = nil;
    
    self.masterDelegate = (id)(OAMasterViewController *)[[self.splitViewController.viewControllers firstObject] topViewController];
    
    UIUserNotificationSettings* notificationSettings = [UIUserNotificationSettings settingsForTypes:UIUserNotificationTypeAlert | UIUserNotificationTypeBadge | UIUserNotificationTypeSound categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:notificationSettings];
    
    // 3. Init CollectionView
    [self initCollectionView];
    
    // 4.集成刷新控件
    [self addHeader];
    [self addFooter];
    
    [self addNetworkObserver];
    [self addBecomeActiveObserver];
    
    // 5.获取最新的公文列表
    [self getUnDoMission];
    
    // 后台定时操作
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        // 定时刷新获取最新公文
        NSTimer *newMissionTimer =  [NSTimer scheduledTimerWithTimeInterval:20.0 target:self selector:@selector(getUnDoMission) userInfo:nil repeats:YES];
        [[NSRunLoop  currentRunLoop] addTimer:newMissionTimer forMode:NSDefaultRunLoopMode];
        
        // 6.删除过期公文
        NSTimer *pdfDelteTimer   =  [NSTimer scheduledTimerWithTimeInterval:20.0 target:self selector:@selector(fileToDelete) userInfo:nil repeats:YES];
        [[NSRunLoop  currentRunLoop] addTimer:pdfDelteTimer forMode:NSDefaultRunLoopMode];
        
        // 定时提交日志
//        NSTimer *logSubmitTimer   =  [NSTimer scheduledTimerWithTimeInterval:60*60.0 target:self selector:@selector(submitLogInfoToServer) userInfo:nil repeats:YES];
//        [[NSRunLoop  currentRunLoop] addTimer:logSubmitTimer forMode:NSDefaultRunLoopMode];
        
        [[NSRunLoop currentRunLoop] run];
    });
    
    // 8.Login
    [self presentLoginView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


#pragma mark - Init Methods Custom
- (void)initNaviTitle
{
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:20.0];
    //    label.shadowColor = [UIColor colorWithWhite:0.0 alpha:0.5];
    label.textAlignment = NSTextAlignmentCenter;
    label.textColor = [UIColor whiteColor]; // change this color
    self.navigationItem.titleView = label;
    label.text = NSLocalizedString(@"移动办公", @"title");
    [label sizeToFit];
}

- (void)initNaviColor
{
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    self.navigationController.navigationBar.barTintColor = kThemeColor;
    self.navigationController.toolbar.barTintColor = kThemeColor;
    self.navigationController.view.tintColor = UIColor.whiteColor;
}

- (void)initRightBtn
{
//    UIBarButtonItem *rightNavBtn = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(editItemClicked)];
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.frame = CGRectMake(0, 0, 30, 30);
    [btn setImage:[UIImage imageNamed:@"User-Trash.png"] forState:UIControlStateNormal];
    [btn addTarget:self action:@selector(editItemClicked) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(clearOldData)];
    [btn addGestureRecognizer:longPress];
    UIBarButtonItem *rightNavBtn = [[UIBarButtonItem alloc] initWithCustomView:btn];
    
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlackTranslucent];
    [self.navigationItem setRightBarButtonItem:rightNavBtn];
}

- (void)initAfterLogin
{
    // 1.判断是否为新用户，若为新用户，删除已有文件（清空）
    [self newUserOldFileDelete];
    
    // 2.登录后，刷新新公文
    [self.collectionView headerBeginRefreshing];
    
    // 3.刷新获取新Task
    [self getUnDoMission];
    [self getDoneMission];
    
    // 4.获取所有用户简单信息
    [self getAllUserToPlist];
}

- (void)initCollectionView
{
    // 0.创建自己的collectionView
    CGRect rect = self.view.bounds;
    
    OAPDFFlowLayout *flowLayout = [[OAPDFFlowLayout alloc] init];
    self.collectionView = [[UICollectionView alloc] initWithFrame:rect collectionViewLayout:flowLayout];
    
    self.collectionView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    self.collectionView.delegate    = self;
    self.collectionView.dataSource  = self;
    [self.view addSubview:self.collectionView];
    
    // observe changes on the collection view's layout so we can update our data source if needed
    [self.collectionView addObserver:self
                          forKeyPath:@"collectionViewLayout"
                             options:NSKeyValueObservingOptionNew
                             context:nil];
    self.collectionView.collectionViewLayout = flowLayout;
    
    // 1.注册cell要用到的xib/class
    [self.collectionView registerClass:[OAPDFCell   class] forCellWithReuseIdentifier:@"OAPDFCell"];
    [self.collectionView registerClass:[OAPDFHeader class] forSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"OAPDFHeader"];
    
    // 2.设置collectionView永远支持垂直滚动(弹簧)
    self.collectionView.alwaysBounceVertical = YES;
    
    // 3.背景色
    //    self.collectionView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"BookShelfCell.png"]];
    self.collectionView.backgroundColor = [UIColor clearColor];
    
    // 4.单选
    self.collectionView.allowsSelection = YES;
    self.collectionView.allowsMultipleSelection = NO;
}

- (void)initNoItemLabel
{
    _noItemsLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 200, kLABEL_HEIGHT*3)];
    _noItemsLabel.center = CGPointMake(self.view.frame.size.width * 0.5, self.view.frame.size.height * 0.5);
    _noItemsLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
    _noItemsLabel.textAlignment = NSTextAlignmentCenter;
    _noItemsLabel.font = [UIFont systemFontOfSize:26.0f];
    _noItemsLabel.textColor = [UIColor lightGrayColor];
    _noItemsLabel.text = @"没有新文件";
    [self.view addSubview:_noItemsLabel];
}

#pragma mark - Some base Mehtods
- (void)presentLoginView
{
    if (self.masterPopoverController) {
        [self.masterPopoverController dismissPopoverAnimated:NO];
    }
    OALoginViewController *loginVC = [[OALoginViewController alloc] initWithNibName:@"OALoginViewController" bundle:nil];
    loginVC.delegate = self;
    [self.splitViewController presentViewController:loginVC animated:NO completion:nil];
}

- (void)editItemClicked
{
    // 编辑模式，可删除公文
    if ([_editState isEqualToNumber:@1]) {
        _editState = @2;
    }else{
        _editState = @1;
    }
    [self.collectionView reloadData];
}

- (BOOL)connected
{
    return [AFNetworkReachabilityManager sharedManager].reachable;
}

- (void)fileToDelete
{
    NSMutableArray *timeOutFile = [NSMutableArray array];
    for (ReaderDocument *pdfFile in [ReaderDocument allInMOC:self.managedObjectContext withTag:@2]) {
        // 当文件已批阅（tag＝2），且文件存在时间超时，且文件未打开
        if (!pdfFile.lastOpen || (([[NSDate date] timeIntervalSinceDate:pdfFile.lastOpen] > _timeExpiredFile)&& !_openedDocument)) {
            [timeOutFile addObject:pdfFile];
        }
    }
    if ([timeOutFile count]>0) {
        [self deletePDFWithArray:timeOutFile];
    }
}

- (void)newUserOldFileDelete
{
    // 1.新用户，原用户文件全删除
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    if ([[userDefaults objectForKey:kNewUser] isEqualToString:@"YES"]) {
        [userDefaults setValue:@"NO" forKey:kNewUser];
        // 2.清除老用户公文
        [self clearOldData];
    }
}

- (void)clearOldData
{
    // 1.清除老用户公文
    [self removeObjectsWithPredicate:@"fileName CONTAINS '.pdf'" withEntityName:kOAPDFDocument];
    [self removeObjectsWithPredicate:@"missiveAddr CONTAINS '.pdf'" withEntityName:kOADoneMissive];
    
    // 2.Master title 显示用户名
    [self.masterDelegate refreashMasterTitleWithName:[[NSUserDefaults standardUserDefaults] objectForKey:kName]];
    // 3.collectionView 刷新数据
    [self.collectionView reloadData];
}

- (BOOL)searchObjectsWithPredicate:(NSString *)predicate withEntityName:(NSString *)entity
{
    // 1. 实例化查询请求
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    
    // 2. 设置谓词条件
    //    request.predicate = [NSPredicate predicateWithFormat:@"name = '张老头'"];
    request.predicate = [NSPredicate predicateWithFormat:predicate];
    
    // 3. 由上下文查询数据
    NSArray *result = [self.managedObjectContext executeFetchRequest:request error:nil];
    
    // 4. 通知_context保存数据
    NSError *error;
    if ([self.managedObjectContext save:&error]) {
        if ([result count] > 0) {
            return NO;// 有搜索结果，返回NO
        }
    } else {
        
    }
    return YES;// 没有搜索结果，返回YES
}

- (void)removeObjectsWithPredicate:(NSString *)predicate withEntityName:(NSString *)entity
{
    // 1. 实例化查询请求
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:entity];
    
    // 2. 设置谓词条件
    //    request.predicate = [NSPredicate predicateWithFormat:@"name = '张老头'"];
    request.predicate = [NSPredicate predicateWithFormat:predicate];
    
    // 3. 由上下文查询数据
    NSArray *result = [self.managedObjectContext executeFetchRequest:request error:nil];
    
    // 4. 输出结果
    if ([entity isEqualToString:kOAPDFDocument]) {
        for (ReaderDocument *object in result) {
            // 删除一条记录
            [self.managedObjectContext deleteObject:object];
            
//            NSError *error;
//            // Sign pdf的文件路径filePath,删除该文件;
//            if ([object fileExistsAndValid:object.fileURL]) {
//                [[[NSFileManager alloc]init] removeItemAtURL:[NSURL fileURLWithPath:object.fileURL] error:&error];
//                MyLog(@"Pdf Delete Error:%@",error.description);
//            }
//            // Sign png的文件路径pngPath,删除该文件;
//            NSString *pngPath = [kDocumentPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.png",object.fileId]];
//            if ([[[NSFileManager alloc]init] fileExistsAtPath:pngPath]) {
//                [[[NSFileManager alloc]init] removeItemAtPath:pngPath error:&error];
//                MyLog(@"Png Delete Error:%@",error.description);
//            }
        }
        NSArray *contents = [[NSFileManager new] contentsOfDirectoryAtPath:kDocumentPath error:NULL];
        NSEnumerator *e = [contents objectEnumerator];
        NSString *filename;
        while ((filename = [e nextObject])) {
            if ([[filename pathExtension] isEqualToString:@"pdf"] || [[filename pathExtension] isEqualToString:@"png"]) {
                [[NSFileManager new] removeItemAtPath:[kDocumentPath stringByAppendingPathComponent:filename] error:NULL];
            }
        }
    }else if ([entity isEqualToString:kOADoneMissive]){
        for (DoneMissive *missive in result) {
            [self.managedObjectContext deleteObject:missive];
        }
    }
    
    // 5. 通知_context保存数据
    NSError *error;
    if ([self.managedObjectContext save:&error]) {
        NSString *info = [NSString stringWithFormat:@"OK:切换用户，原用户公文清除成功."];
        [self newLogWithInfo:info time:[NSDate date]];
    } else {
        NSString *info = [NSString stringWithFormat:@"Error:切换用户，原用户公文清除失败.%@",error.description];
        [self newLogWithInfo:info time:[NSDate date]];
    }
}

- (void)deletePDFWithObject:(ReaderDocument *)reader
{
    [self.collectionView performBatchUpdates:^{
        [self performSelectorInBackground:@selector(documentDeleteInMOCWithTheDeleteDocument:) withObject:reader];
    }
                                  completion:^(BOOL finished) {
                                      _deletedDocument = nil;
                                      
                                      MyLog(@"Delete guid:%@ OK!\n",reader.guid);
                                      NSString *info = [NSString stringWithFormat:@"OK:过期公文-%@-删除成功.",reader.fileName];
                                      [self newLogWithInfo:info time:[NSDate date]];
                                  }];
    
}

- (void)deletePDFWithArray:(NSMutableArray *)readerArray
{
    [self.collectionView performBatchUpdates:^{
        [self performSelectorInBackground:@selector(documentDeleteInMOCWithTheDeleteArray:) withObject:readerArray];
    }
                                  completion:^(BOOL finished) {
                                  }];
}


#pragma mark - Split view

- (void)splitViewController:(UISplitViewController *)splitController willHideViewController:(UIViewController *)viewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController:(UIPopoverController *)popoverController
{
//    barButtonItem.title = NSLocalizedString(@"Home", @"Master");
    barButtonItem.image = [UIImage imageNamed:@"User-Home.png"];
    [self.navigationItem setLeftBarButtonItem:barButtonItem animated:YES];
    self.masterPopoverController = popoverController;
}

- (void)splitViewController:(UISplitViewController *)splitController willShowViewController:(UIViewController *)viewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    // Called when the view is shown again in the split view, invalidating the button and popover controller.
    [self.navigationItem setLeftBarButtonItem:nil animated:YES];
    self.masterPopoverController = nil;
}


#pragma mark - UICollectionViewDataSource methods

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [[self.fetchedResultsController sections] count];
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    OAPDFHeader *header = nil;
    if (kind == UICollectionElementKindSectionHeader) {
        header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"OAPDFHeader" forIndexPath:indexPath];
        id <NSFetchedResultsSectionInfo> sectionInfo = [[[self fetchedResultsController] sections] objectAtIndex:[indexPath section]];
        switch ([sectionInfo name].intValue) {
            case 1:
                [[header titleLabel] setText:@"最新文件"];
                break;
                
            case 2:
                [[header titleLabel] setText:@"已签文件"];
                break;
                
            default:
                break;
        }
    }
    return header;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    if (0 == section) {
        [UIApplication sharedApplication].applicationIconBadgeNumber = [sectionInfo numberOfObjects];
    }
    return [sectionInfo numberOfObjects];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    // 1. 声明静态标识
    static NSString* oaPDFCellIdentifier = @"OAPDFCell";
    
    // 2. 启用重用机制
    OAPDFCell *cell = (OAPDFCell *)[collectionView dequeueReusableCellWithReuseIdentifier:oaPDFCellIdentifier forIndexPath:indexPath];
    
    // 3.
    
    // 4.
    ReaderDocument *object = (ReaderDocument *)[self.fetchedResultsController objectAtIndexPath:indexPath];
//    cell.document = object;
    
    // 5.

    cell.titleLabel.text = [[object valueForKey:kFileName] stringByDeletingPathExtension];
//    NSString *titleStr = [cell.titleLabel.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
//    CGSize titleSize = [titleStr sizeWithAttributes:@{NSFontAttributeName: cell.titleLabel.font}];
//    if (titleSize.width <= cell.titleLabel.frame.size.width) {
//        cell.titleLabel.center = CGPointMake(cell.titleLabel.center.x,cell.titleLabel.center.y + 20);
//    }
    
    // 6.编辑状态
    [cell.deleteBtn addTarget:self action:@selector(pdfCellDelete:) forControlEvents:UIControlEventTouchUpInside];
    if ([_editState isEqualToNumber:@2]) {
        cell.deleteBtn.hidden = NO;
    }else{
        cell.deleteBtn.hidden = YES;
    }
    
    // 7. Tag 标签
    if ([object.urgencyLevel isEqualToString:@"急"]) {
        cell.tagView.image = [UIImage imageNamed:@"File-Urgent.png"];
    }else if ([object.urgencyLevel isEqualToString:@"加急"])
    {
        cell.tagView.image = [UIImage imageNamed:@"File-V-Urgent.png"];
    }else{
        cell.tagView.image = [UIImage imageNamed:@"File-Common.png"];
    }
    
    UIImage *thumbImage = [UIImage imageWithData:[object valueForKey:kFileThumbImage]];
    if (!thumbImage) {
        cell.pdfThumbView.image = [UIImage imageNamed:@"File-Download.png"];
        cell.dateLabel.hidden = YES;
        cell.missiveType.hidden = YES;
        if (!cell.isDownLoading) {
            cell.pdfThumbView.layer.borderWidth = 0.0f;
        }
    }else{
        cell.pdfThumbView.image = thumbImage;
        //
        cell.isDownLoading = NO;
        // 文件下载完成，框选状态取消
        cell.pdfThumbView.layer.borderWidth = 0.0f;
        cell.pValue.hidden = YES;
        cell.pView.hidden = YES;
        
        // 8.zzz表示时区，zzz可以删除，这样返回的日期字符将不包含时区信息。
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yy-MM-dd HH:mm"];
        cell.dateLabel.text = [dateFormatter stringFromDate:[object valueForKey:kTaskStartTime]];
        cell.dateLabel.hidden = NO;
        
        // 显示公文类型
        cell.missiveType.hidden = NO;
        NSString *type = [object valueForKey:@"missiveType"];
        if ([type isEqualToString:@"missiveReceive"]) {
            cell.missiveType.text = @"收   文";
        }else if ([type isEqualToString:@"missivePublish"]){
            cell.missiveType.text = @"发   文";
        }else if ([type isEqualToString:@"missiveSign"]){
            cell.missiveType.text = @"签   报";
        }else if ([type isEqualToString:@"faxCablePublish"]){
            cell.missiveType.text = @"传真电报";
        }else{
            cell.missiveType.text = @"";
        }
        
    }
    
    return cell;
}
#pragma mark - UICollectionView Delegate methods
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    // 非编辑状态，执行；编辑状态，不执行；
    if ([_editState isEqualToNumber:@1]) {
        OAPDFCell *cell = (OAPDFCell *)[collectionView cellForItemAtIndexPath:indexPath];
        ReaderDocument *object = (ReaderDocument *)[self.fetchedResultsController objectAtIndexPath:indexPath];

        // 判断当前文件是否已下载；
        if(object.fileURL && [object fileExistsAndValid:object.fileURL])
        {
            ReaderViewController *readerVC = [[ReaderViewController alloc] initWithReaderDocument:object];
            readerVC.delegate = self;
            readerVC.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
            [self presentViewController:readerVC animated:YES completion:^{
                // 阅后即删除操作
                _selectedIndexPath = indexPath;
                _openedDocument = object;
            }];
        }else{
            if (!cell.isDownLoading) {
                cell.isDownLoading = YES;
//                cell.pdfThumbView.layer.borderWidth = 2.0f;
//                cell.pdfThumbView.layer.borderColor = [UIColor brownColor].CGColor;
//                MyLog(@"点击开始下载！");
                NSString *info = [NSString stringWithFormat:@"Error:公文-%@-（未下载）被点击，开始下载.",object.fileName];
                [self newLogWithInfo:info time:[NSDate date]];
                
                // 下载
                [self downFileWithUrl:object.fileLink readerDocument:object];
            }else{
                [self showAlertTitle:[NSString stringWithFormat:@"公文:%@",cell.titleLabel.text] message:@"正在下载..."];
            }
        }
    }else{
        [self editItemClicked];
    }
}

#pragma mark - UICollectionViewLayout
- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attr = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
    
    attr.transform = CGAffineTransformRotate(CGAffineTransformMakeScale(0.2, 0.2), M_PI);
    attr.center    = CGPointMake(CGRectGetMidX(self.collectionView.bounds), CGRectGetMaxY(self.collectionView.bounds));
    
    return attr;
}

- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewLayoutAttributes *attributes = [self.collectionView layoutAttributesForItemAtIndexPath:indexPath];
//    attributes.alpha = 0.0;
    return attributes;
}

#pragma mark - Fetched results controller

- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:kOAPDFDocument inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:30];
    
    // Set the predicate @"age < 60 && name LIKE '*五'"];
//    NSUserDefaults *userDefaultes = [NSUserDefaults standardUserDefaults];
//    NSString *userName = [userDefaultes objectForKey:kUserName];
//    NSString *password = [userDefaultes objectForKey:kPassword];
//    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"userName = %@ && password = %@",userName,password]];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor1 = [[NSSortDescriptor alloc] initWithKey:kFileTag ascending:YES];
    NSSortDescriptor *sortDescriptor2 = [[NSSortDescriptor alloc] initWithKey:kTaskStartTime ascending:NO];
//    NSArray *sortDescriptors = @[sortDescriptor2];
    NSArray *sortDescriptors = @[sortDescriptor1,sortDescriptor2];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:kFileTag cacheName:@"Home"];
//    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Home"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
	    MyLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}

//- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
//           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
//{
//    NSMutableDictionary *change = [NSMutableDictionary new];
//    
//    switch((NSUInteger)type) {
//        case NSFetchedResultsChangeInsert:
//            change[@(type)] = @(sectionIndex);
//            break;
//        case NSFetchedResultsChangeDelete:
//            change[@(type)] = @(sectionIndex);
//            break;
//    }
//    MyLog(@"didChangeSection Section: %li Type: %@", (unsigned long)sectionIndex, type == NSFetchedResultsChangeDelete ? @"Delete" : @"Insert");
//    
//    [_sectionChanges addObject:change];
//}
//
//- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
//       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
//      newIndexPath:(NSIndexPath *)newIndexPath
//{
//    
//    NSMutableDictionary *change = [NSMutableDictionary new];
//    switch(type)
//    {
//        case NSFetchedResultsChangeInsert:
//            change[@(type)] = newIndexPath;
//            break;
//        case NSFetchedResultsChangeDelete:
//            change[@(type)] = indexPath;
//            break;
//        case NSFetchedResultsChangeUpdate:
//            change[@(type)] = indexPath;
//            break;
//        case NSFetchedResultsChangeMove:
//            change[@(type)] = @[indexPath, newIndexPath];
//            break;
//    }
//    
//    MyLog(@"didChangeObject IndexPath: %li,%li Type: %@", (long)indexPath.section,(long)indexPath.row, type == NSFetchedResultsChangeDelete ? @"Delete" : @"Other");
//    
//    [_objectChanges addObject:change];
//}
//
//- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
//{
//    MyLog(@"controllerDidChangeContent sectionChanges: %li", (unsigned long)[_sectionChanges count]);
//    
//    [self.collectionView performBatchUpdates:^{
//        
//        if ([_sectionChanges count] > 0)
//        {
//            MyLog(@"BEFORE performBatchUpdates for Sections");
//            
//            //        @try {
//            
//            
//            
//            for (NSDictionary *change in _sectionChanges)
//            {
//                [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {
//                    
//                    NSFetchedResultsChangeType type = [key unsignedIntegerValue];
//                    switch ((NSUInteger)type)
//                    {
//                        case NSFetchedResultsChangeInsert:
//                            [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
//                            break;
//                        case NSFetchedResultsChangeDelete:
//                            MyLog(@"BEFORE deleteSections");
//                            NSUInteger toDeleteSection = [obj unsignedIntegerValue];
//                            [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:toDeleteSection]];
//                            MyLog(@"AFTER deleteSections");
//                            break;
//                        case NSFetchedResultsChangeUpdate:
//                            [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
//                            break;
//                    }
//                }];
//            }
//            
//            //        }
//            //        @catch (NSException *exception) {
//            //            MyLog(@"Exception caught");
//            //            //MyLog(@"Exception caught: %@", exception.description);
//            //            //[self.collectionView reloadData];
//            //        }
//            
//            MyLog(@"AFTER performBatchUpdates for Sections");
//        }
//        
//        
//        MyLog(@"controllerDidChangeContent objectChanges: %li sectionChanges: %li", (unsigned long)[_objectChanges count], (unsigned long)[_sectionChanges count]);
//        
//        if ([_objectChanges count] > 0) {
//            
//            MyLog(@"[_objectChanges count] > 0 && [_sectionChanges count] == 0)");
//            
//            //        if ([self shouldReloadCollectionViewToPreventKnownIssue] || self.collectionView.window == nil) {
//            //            // This is to prevent a bug in UICollectionView from occurring.
//            //            // The bug presents itself when inserting the first object or deleting the last object in a collection view.
//            //            // http://stackoverflow.com/questions/12611292/uicollectionview-assertion-failure
//            //            // This code should be removed once the bug has been fixed, it is tracked in OpenRadar
//            //            // http://openradar.appspot.com/12954582
//            //            [self.collectionView reloadData];
//            //
//            //            MyLog(@"CV reloadData");
//            //
//            //        } else {
//            
//            MyLog(@"BEGIN performBatchUpdates for Objects");
//            
//            [self.collectionView performBatchUpdates:^{
//                
//                for (NSDictionary *change in _objectChanges) {
//                    
//                    [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {
//                        
//                        NSFetchedResultsChangeType type = [key unsignedIntegerValue];
//                        switch (type)
//                        {
//                            case NSFetchedResultsChangeInsert:
//                                [self.collectionView insertItemsAtIndexPaths:@[obj]];
//                                break;
//                            case NSFetchedResultsChangeDelete:
//                                [self.collectionView deleteItemsAtIndexPaths:@[obj]];
//                                break;
//                            case NSFetchedResultsChangeUpdate:
//                                [self.collectionView reloadItemsAtIndexPaths:@[obj]];
//                                break;
//                            case NSFetchedResultsChangeMove:
//                                [self.collectionView moveItemAtIndexPath:obj[0] toIndexPath:obj[1]];
//                                break;
//                        } // switch
//                        
//                    }]; // enumerate blocks
//                    
//                } // for
//                
//            } completion:nil]; // performBatchUpdates
//        } // if objectchange
//        
//    } completion:^(BOOL finished){
//        MyLog(@"completion finished");
//    }];
//    
//    [_sectionChanges removeAllObjects];
//    [_objectChanges removeAllObjects];
//}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id<NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    __weak UICollectionView *collectionView = self.collectionView;
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            [blockOperation addExecutionBlock:^{
                [collectionView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
            }];
            break;
        }
            
        case NSFetchedResultsChangeDelete: {
            [blockOperation addExecutionBlock:^{
                if ([collectionView numberOfItemsInSection:sectionIndex] == 0) {
                    [collectionView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
                }
            }];
            break;
        }
            
        case NSFetchedResultsChangeUpdate: {
            [blockOperation addExecutionBlock:^{
                [collectionView reloadSections:[NSIndexSet indexSetWithIndex:sectionIndex]];
            }];
            break;
        }
            
        default:
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
    __weak UICollectionView *collectionView = self.collectionView;
    switch (type) {
        case NSFetchedResultsChangeInsert: {
            if ([self.collectionView numberOfSections] > 0) {
                if ([self.collectionView numberOfItemsInSection:indexPath.section] == 0) {
                    shouldReloadCollectionView = YES;
                } else {
                    [blockOperation addExecutionBlock:^{
                        [collectionView insertItemsAtIndexPaths:@[newIndexPath]];
                    }];
                }
            } else {
                shouldReloadCollectionView = YES;
            }
            break;
        }
            
        case NSFetchedResultsChangeDelete: {
            if ([self.collectionView numberOfItemsInSection:indexPath.section] == 1) {
                shouldReloadCollectionView = YES;
            } else {
                [blockOperation addExecutionBlock:^{
                    [collectionView deleteItemsAtIndexPaths:@[indexPath]];
                }];
            }
            break;
        }
            
        case NSFetchedResultsChangeUpdate: {
            [blockOperation addExecutionBlock:^{
                [collectionView reloadItemsAtIndexPaths:@[indexPath]];
            }];
            break;
        }
            
        case NSFetchedResultsChangeMove: {
            [blockOperation addExecutionBlock:^{
                [collectionView moveItemAtIndexPath:indexPath toIndexPath:newIndexPath];
            }];
            break;
        }
            
        default:
            break;
    }
}


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    shouldReloadCollectionView = NO;
    blockOperation = [NSBlockOperation new];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // Checks if we should reload the collection view to fix a bug @ http://openradar.appspot.com/12954582
//    if (shouldReloadCollectionView) {
//        [self.collectionView reloadData];
//    } else {
//        [self.collectionView performBatchUpdates:^{
//            [blockOperation start];
//        } completion:^(BOOL finished) {
//        }];
//    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.collectionView reloadData];
    });
}

#pragma mark - OAPDFCellDown and Delete

- (void)pdfCellDelete:(UIButton *)sender
{
    NSIndexPath *indexPath = [self.collectionView indexPathForCell:(OAPDFCell *)sender.superview.superview];
    _deletedDocument  = (ReaderDocument *)[self.fetchedResultsController objectAtIndexPath:indexPath];;
    _selectedIndexPath= indexPath;
    NSString *pdfName = [[_deletedDocument valueForKey:kFileName] stringByDeletingPathExtension];
    
    NSString *message = [NSString stringWithFormat:@"删除文件:%@",pdfName];
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"提醒" message:message delegate:self cancelButtonTitle:@"确定" otherButtonTitles:@"取消", nil];
    [alertView show];
}

- (void)documentDeleteInMOCWithTheDeleteDocument:(ReaderDocument *)reader
{
    [ReaderDocument deleteInMOC:self.managedObjectContext object:reader];
    
//    [self removeObjectsWithPredicate:[NSString stringWithFormat:@"fileName CONTAINS '%@'",reader.fileName] withEntityName:kOAPDFDocument];
//    [self.managedObjectContext deleteObject:reader];
//    NSError *error = nil;
//    if ([self.managedObjectContext save:&error]) {
//        MyLog(@"删除成功");
//    } else {
//        MyLog(@"删除失败：%s %@", __FUNCTION__, error); assert(NO);
//    }
}

- (void)documentDeleteInMOCWithTheDeleteArray:(NSMutableArray *)readerArray
{
    [ReaderDocument deleteInMOC:self.managedObjectContext array:readerArray];
}


#pragma mark - ReaderViewControllerDelegate methods

- (void)dismissReaderViewController:(ReaderViewController *)viewController withDocument:(ReaderDocument *)document withTag:(NSNumber *)tag
{
    [self dismissViewControllerAnimated:NO completion:^{
        //4. 正在打开的文件为空；
        _openedDocument = nil;
        if ([tag isEqualToNumber:@0]) {
            // 1. 更新文件标签
            // fileTag = @1 标签初始化
            // fileTag = @2 标签 文件已签发
            
            // 刷新数据
            [self getUnDoMission];
        }else if([tag isEqualToNumber:@1]){
            // 3. 取消该公文本地通知
            [self cancelNotificationWithObject:document.fileName andKey:document.guid];
            
            [self performSelector:@selector(fileToDelete) withObject:nil afterDelay:3.0];
            
        }else{
            [self presentLoginView];
        }
    }];
}

#pragma mark - OALoginViewControllerDelegate methods
- (void)dismissOALoginViewController:(OALoginViewController *)viewController
{
    [self initAfterLogin];
    [self dismissViewControllerAnimated:NO completion:nil];
}

#pragma mark Alert View Methods
- (void)timerFireMethod:(NSTimer*)theTimer//弹出框
{
    UIAlertView *promptAlert = (UIAlertView *)[theTimer userInfo];
    [promptAlert dismissWithClickedButtonIndex:0 animated:NO];
    promptAlert = NULL;
}

- (void)showAlertTitle:(NSString *)title message:(NSString *)message
{   //时间
    UIAlertView *promptAlert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
    [NSTimer scheduledTimerWithTimeInterval:2.5f
                                     target:self
                                   selector:@selector(timerFireMethod:)
                                   userInfo:promptAlert
                                    repeats:YES];
    [promptAlert show];
}

#pragma mark - UIAlertView Delegate 右顶角按钮提示
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    switch (buttonIndex) {
        case 0: // 确认
        {
            // 跳转到登录界面；
//            [self presentLoginView];
            // 删除公文
            [self deletePDFWithObject:_deletedDocument];
            // 当一个文件被删除成功后，取消编辑（删除）模式
            [self editItemClicked];
        }
            break;
        case 1: // 取消
            break;
        default:
            break;
    }
}

#pragma mark - MasterToDetail Delegate
- (void)exitToLoginVC
{
    [self presentLoginView];
}

- (void)downloadDoneMissiveWithObject:(NSManagedObject *)missive
{
    NSString *predicate = [NSString stringWithFormat:@"fileId = '%@'",[missive valueForKey:kTaskId]];
    NSString *fileName  = [NSString stringWithFormat:@"%@.pdf",[missive valueForKey:kMissiveTitle]];
    if ([self searchObjectsWithPredicate:predicate withEntityName:kOAPDFDocument]) {
        ReaderDocument *object  = [ReaderDocument initOneInMOC:self.managedObjectContext name:fileName tag:@2];
        object.fileId           = [missive valueForKey:kTaskId];
        object.missiveType      = [[missive valueForKey:kMissiveAddr] componentsSeparatedByString:@"/"][2];
        object.urgencyLevel     = [missive valueForKey:kUrgentLevel];
        object.taskName         = [missive valueForKey:kTaskName];
        object.fileLink         = [NSString stringWithFormat:@"%@%@",kBaseURL,[missive valueForKey:kMissiveAddr]];
        object.taskStartTime    = [missive valueForKey:kMissiveDoneTime];
        assert(object != nil); // Object insert failure should never happen
        [self.collectionView reloadData];
        
        // 3.公文后台下载文件
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            [self downFileWithUrl:object.fileLink readerDocument:object];
        });
    }else{
        [self showAlertTitle:@"提示" message:@"您选择的公文已在列表中！"];
    }
}

#pragma mark - NSKeyValueObserving methods
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"collectionViewLayout"]) {
        // reset values
        
        [self.collectionView reloadData];
    }
}

#pragma mark - MJRefresh
- (void)addHeader
{
    __unsafe_unretained typeof(self) vc = self;
    // 添加下拉刷新头部控件
    [self.collectionView addHeaderWithCallback:^{
        // 进入刷新状态就会回调这个Block
        [vc getUnDoMission];
        [vc fileToDelete];
        
        [vc.collectionView reloadData];
        // 结束刷新
        [vc.collectionView headerEndRefreshing];
    } dateKey:@"collection"];
    // dateKey用于存储刷新时间，也可以不传值，可以保证不同界面拥有不同的刷新时间
}

- (void)addFooter
{
    __unsafe_unretained typeof(self) vc = self;
    // 添加上拉刷新尾部控件
    [self.collectionView addFooterWithCallback:^{
        // 进入刷新状态就会回调这个Block
        [vc getUnDoMission];
        [vc fileToDelete];
        
        [vc.collectionView reloadData];
        // 结束刷新
        [vc.collectionView footerEndRefreshing];
    }];
}

#pragma mark - DownLoad pdf with url

- (void)downFileWithUrl:(NSString *)linkUrl readerDocument:(ReaderDocument *)readerPDF
{
    // 0.判断网络是否连接
    if ([self connected]) {
        // 1.设置对应Cell的下载状态
        NSIndexPath *indexPath = [self.fetchedResultsController indexPathForObject:readerPDF];
        OAPDFCell *cell = (OAPDFCell *)[self.collectionView cellForItemAtIndexPath:indexPath];
        cell.pView.hidden  = NO;
        cell.pValue.hidden = NO;
        //[self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
        
        // 2.设置下载请求
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:linkUrl]];
        
        NSString *cacheDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
//        NSString *filePath = [cacheDirectory stringByAppendingPathComponent:readerPDF.fileName];
        NSString *filePath = [cacheDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.pdf",readerPDF.fileId]];
        
        // 3.检查文件是否已经下载了一部分
        unsigned long long downloadedBytes = 0;
        if ([[[NSFileManager alloc]init] fileExistsAtPath:filePath]) {
            //获取已下载的文件长度
            downloadedBytes = [self fileSizeForPath:filePath];
            if (downloadedBytes > 0) {
                NSMutableURLRequest *mutableURLRequest = [request mutableCopy];
                NSString *requestRange = [NSString stringWithFormat:@"bytes=%llu-", downloadedBytes];
                [mutableURLRequest setValue:requestRange forHTTPHeaderField:@"Range"];
                request = mutableURLRequest;
            }
        }
        // 4.不使用缓存，避免断点续传出现问题
        [[NSURLCache sharedURLCache] removeCachedResponseForRequest:request];
        
        // 5.下载请求
        AFURLConnectionOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
        //下载路径
        operation.outputStream = [NSOutputStream outputStreamToFileAtPath:filePath append:YES];
        //下载进度回调
        [operation setDownloadProgressBlock:^(NSUInteger bytesRead, long long totalBytesRead, long long totalBytesExpectedToRead) {
            cell.pView.progress = (float)totalBytesRead / totalBytesExpectedToRead;
            cell.pValue.text = [NSString stringWithFormat:@"%2.0f%%",((float)totalBytesRead / totalBytesExpectedToRead) * 100];
        }];
        //成功和失败回调
        [operation setCompletionBlock:^{
            // 1. 隐藏Cell的view
            cell.pView.hidden = YES;
            cell.pValue.hidden = YES;
            cell.pValue.text = @"0%";
            cell.isDownLoading = NO;
            // 2.文件下载成功
            NSString *existFileURL = [cacheDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.pdf",readerPDF.fileId]];
            if ([self fileExistsAndValid:existFileURL]) {
                // 3. 补全－公文（ReaderDocument）信息
                [ReaderDocument complementInMOC:self.managedObjectContext object:readerPDF path:cacheDirectory];
                // 4. 本地推送新公文信息
                if ([readerPDF.fileTag isEqualToNumber:@1]) {
                    [self createNotificationWithObject:readerPDF.fileName andKey:readerPDF.guid];
                }
                
                NSString *info = [NSString stringWithFormat:@"OK:公文-%@-下载成功.%@",readerPDF.fileName,linkUrl];
                [self newLogWithInfo:info time:[NSDate date]];
            }else{
                //
                cell.pValue.hidden = NO;
                cell.pValue.text = @"公文不存在!";
                
                NSString *info = [NSString stringWithFormat:@"Error:下载公文,公文不存在错误。%@",linkUrl];
                [self newLogWithInfo:info time:[NSDate date]];
            }
            [self.collectionView reloadData];
        }];
        [operation start];
    }else{
        NSString *info = [NSString stringWithFormat:@"Error:文件下载中，网络中断错误。%@",linkUrl];
        [self newLogWithInfo:info time:[NSDate date]];
    }
}

//获取已下载的文件大小
- (unsigned long long)fileSizeForPath:(NSString *)path
{
    signed long long fileSize = 0;
    NSFileManager *fileManager = [NSFileManager new]; // default is not thread safe
    if ([fileManager fileExistsAtPath:path]) {
        NSError *error = nil;
        NSDictionary *fileDict = [fileManager attributesOfItemAtPath:path error:&error];
        if (!error && fileDict) {
            fileSize = [fileDict fileSize];
        }
    }
    return fileSize;
}

//判断PDF文件存在并有效
- (BOOL)fileExistsAndValid:(NSString *)fileURL
{
    BOOL state = NO; // Status
    NSString *filePath = fileURL; // Path
    
    const char *path = [filePath fileSystemRepresentation];
    
    int fd = open(path, O_RDONLY); // Open the file
    
    if (fd > 0) // We have a valid file descriptor
    {
        const char sig[1024]; // File signature buffer
        
        ssize_t len = read(fd, (void *)&sig, sizeof(sig));
        
        state = (strnstr(sig, "%PDF", len) != NULL);
        
        close(fd); // Close the file
    }
    
    return state;
}

#pragma mark - Local Notification
- (void)createNotificationWithObject:(NSString *)objectName andKey:(NSString *)keyGUID
{
    // 创建一个本地推送
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    //设置10秒之后
    NSDate *pushDate = [NSDate dateWithTimeIntervalSinceNow:0];
    if (notification != nil) {
        // 设置推送时间
        notification.fireDate = pushDate;
        // 设置时区
        notification.timeZone = [NSTimeZone defaultTimeZone];
        // 设置重复间隔
        notification.repeatInterval = kCFCalendarUnitDay;
        // 推送声音
        notification.soundName = UILocalNotificationDefaultSoundName;
        // 推送内容
        notification.alertBody = [NSString stringWithFormat:@"您有新的公文：%@",objectName];
        // 推送时小图标的设置，PS:这个东西不知道还有啥用
        notification.alertLaunchImage=[[NSBundle mainBundle]pathForResource:@"Icon-Small" ofType:@"png"];
        // 显示在icon上的红色圈中的数子
//        _badgeNumber++;
//        notification.applicationIconBadgeNumber = _badgeNumber;
        notification.applicationIconBadgeNumber = [UIApplication sharedApplication].applicationIconBadgeNumber;
        NSDictionary *info = [NSDictionary dictionaryWithObject:objectName forKey:keyGUID];
        notification.userInfo = info;
        // 添加推送到UIApplication
        UIApplication *app = [UIApplication sharedApplication];
        // 计划本地推送
//        [app scheduleLocalNotification:notification];
        // 即时推送
        [app presentLocalNotificationNow:notification];
    }
}

- (void)cancelNotificationWithObject:(NSString *)objectName andKey:(NSString *)keyGUID
{
    // 获得 UIApplication
    UIApplication *app = [UIApplication sharedApplication];
    //获取本地推送数组
    NSArray *localArray = [app scheduledLocalNotifications];
    for (UILocalNotification *localNotification in localArray) {
        NSDictionary *dict = localNotification.userInfo;
        NSString *inKey = [[dict objectForKey:keyGUID] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        if ([inKey isEqualToString:objectName]) {
            [app cancelLocalNotification:localNotification];
//            _badgeNumber--;
//            [UIApplication sharedApplication].applicationIconBadgeNumber = _badgeNumber;
            break;
        }
    }
}

#pragma mark - HTTP request with AFNetwork

- (void)getUnDoMission
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *userName = [userDefaults objectForKey:kUserName];
    NSString *netConnect = [userDefaults objectForKey:kNetConnect];
    __block NSString *authorizationHeader = [userDefaults objectForKey:kAuthorizationHeader];
    // 用户名和密码非空和网络OK时，获取最新任务列表
    if (userName && [netConnect isEqualToString:@"OK"] && authorizationHeader) {
        NSString *serverURL = [[NSString stringWithFormat:@"%@%@",kTaskURL,userName] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];//转码成UTF-8  否则可能会出现错
        
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
            NSDictionary *result = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:nil];
            // 获取未办公文到词典中，与最新公文列表对比，
            NSMutableDictionary *unReadDic = [NSMutableDictionary dictionary];
            for (ReaderDocument *pdf in [ReaderDocument allInMOC:self.managedObjectContext withTag:@1]) {
                if (pdf.taskInfo) {
                    NSDictionary *taskInfoDic = [NSJSONSerialization JSONObjectWithData:pdf.taskInfo options:NSJSONReadingMutableLeaves error:nil];
                    [unReadDic setObject:pdf forKey:[taskInfoDic objectForKey:@"id"]];
                }
            }
            
            for (int i = 0; i < [(NSArray *)result count]; i++) {
                // 1.判断文件中是否已存在该公文
                NSDictionary *taskInfoDic = (NSDictionary *)[(NSArray *)result objectAtIndex:i];
                NSString *isPadDealMissive = [taskInfoDic objectForKey:@"isPadDealMissive"];
                if (![unReadDic objectForKey:[taskInfoDic objectForKey:@"id"]] && [isPadDealMissive isEqualToString:@"yes"]) {
                    // 公文名非空，下载公文；
                    NSString *missiveTitle = [taskInfoDic objectForKey:@"missiveTitle"];
                    if (![missiveTitle isKindOfClass:[NSNull class]] && ([missiveTitle length]>0)) {
//                        // 2.判断公文是否存在（不存在－“文件不存在.”）
//                        AFHTTPRequestOperationManager *managerPdf = [AFHTTPRequestOperationManager manager];
//                        [managerPdf.requestSerializer setValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
//                        
//                        [managerPdf GET:downLink parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
//                        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
////                            MyLog(@"%@",operation.responseString);//1:ok 2:not exists
//                            if([operation.responseString isEqualToString:@"ok"]){
                                // 3.新建公文；
                                NSString *fileName = [NSString stringWithFormat:@"%@.pdf",missiveTitle];
                                ReaderDocument *object  = [ReaderDocument initOneInMOC:self.managedObjectContext name:fileName tag:@1];
                                assert(object != nil); // Object insert failure should never happen
                                object.taskInfo         = [NSJSONSerialization dataWithJSONObject:taskInfoDic options:NSJSONWritingPrettyPrinted error:nil];
                                object.fileLink         = [NSString stringWithFormat:@"%@download/pdf/%@/%@/%@.pdf",kBaseURL,[taskInfoDic objectForKey:@"missiveType"],[taskInfoDic objectForKey:@"processInstanceId"],[taskInfoDic objectForKey:@"lastTaskId"]];
                                object.fileId           = [NSString stringWithFormat:@"%@",[taskInfoDic objectForKey:@"id"]];
                                object.urgencyLevel     = [taskInfoDic objectForKey:@"urgencyLevel"];
                                object.missiveType      = [taskInfoDic objectForKey:@"missiveType"];
                                object.taskName         = [taskInfoDic objectForKey:@"name"];
                        
                                NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
                                [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                                NSDate *taskStartTime   = [dateFormatter dateFromString:[taskInfoDic valueForKey:kTaskStartTime]];
                                object.taskStartTime    = taskStartTime;
                                [self.collectionView reloadData];
                                
                                // 3.公文后台下载文件
                                dispatch_async(dispatch_get_global_queue(0, 0), ^{
                                    [self downFileWithUrl:object.fileLink readerDocument:object];
                                });
//                            }
//                        }];
                    }
                }else
                {
                    [unReadDic removeObjectForKey:[taskInfoDic objectForKey:@"id"]];
                }
            }
            // 本地未办公文 相比：最新公文列表单中，本地存在一些（PC端已处理但pad端未处理），本地未办公文改为已办公文
            if ([unReadDic count] > 0) {
                for (NSString *key in unReadDic) {
                    ReaderDocument *pdf = [unReadDic objectForKey:key];
                    // pdf.tag = 2 公文处理掉
                    [ReaderDocument refreashInMOC:self.managedObjectContext object:pdf];
                    // 取消该本地通知
                    [self cancelNotificationWithObject:pdf.fileName andKey:pdf.guid];
                }
            }
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSString *info = [NSString stringWithFormat:@"Error:获取最新公文失败错误.%@",error.description];
            [self newLogWithInfo:info time:[NSDate date]];
            
            NSString *errorFailingURLKey = [[error.userInfo objectForKey:@"NSErrorFailingURLKey"] absoluteString];
            NSRange range = [errorFailingURLKey rangeOfString:@"login"];
            if (range.length > 0) {
                if (authorizationHeader) {
                    [self showAlertTitle:@"提醒" message:@"用户验证信息已过期，请重新登录。"];
                }else{
                    [self showAlertTitle:@"提醒" message:@"首次登陆，请输入用户名和密码登录。"];
                }
                
                //将上述数据全部存储到NSUserDefaults中
                NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
                [userDefaults removeObjectForKey:kAuthorizationHeader];
                [userDefaults synchronize];
                
                NSString *info = [NSString stringWithFormat:@"Error:用户验证信息已过期，请重新登录.%@",error.description];
                [self newLogWithInfo:info time:[NSDate date]];
            }
        }];
    }
}

- (void)getDoneMission
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *userName = [userDefaults objectForKey:kUserName];
    NSString *netConnect = [userDefaults objectForKey:kNetConnect];
    __block NSString *authorizationHeader = [userDefaults objectForKey:kAuthorizationHeader];
    // 用户名和密码非空和网络OK时，获取最新任务列表
    if (userName && [netConnect isEqualToString:@"OK"] && authorizationHeader) {
        int pageSize = kPageSize;
        int pageNum  = 1;
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
                [self.masterDelegate insertNewDoneMissionWithObject:dic];
            }
            
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSString *info = [NSString stringWithFormat:@"Error:获取最新公文失败错误.%@",error.description];
            [self newLogWithInfo:info time:[NSDate date]];
        }];
    }
}

#pragma mark - Notification for AFNetworkingOperationDidFinishNotification
- (void)addNetworkObserver
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(HTTPOperationDidFinish:)
                                                 name:AFNetworkingOperationDidFinishNotification
                                               object:nil];
}

- (void)HTTPOperationDidFinish:(NSNotification *)notification
{
    static NSError *oldError = nil;
    AFHTTPRequestOperation *operation = (AFHTTPRequestOperation *)[notification object];
    if (![operation isKindOfClass:[AFHTTPRequestOperation class]]) {
        oldError = nil;
        return;
    }
    if (operation.error != oldError && !oldError) {
        oldError = operation.error;
        [self showAlertTitle:@"服务器连接状态：" message:@"已断开"];
    }
}

- (void)addBecomeActiveObserver
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(presentLoginView) name:UIApplicationDidEnterBackgroundNotification object:nil];
}

#pragma mark - AllUserList
- (void)getAllUserToPlist
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *plistPath = [userDefaults objectForKey:kUserPlist];
        __block NSMutableArray *docPlist = [[NSMutableArray alloc] initWithContentsOfFile:plistPath];
        if (!docPlist) {
            docPlist = [NSMutableArray array];
            
            NSString *authorizationHeader = [userDefaults objectForKey:kAuthorizationHeader];
            NSString *serverURL = [[NSString stringWithFormat:@"%@",kUserURL] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];//转码成UTF-8  否则可能会出现错
            AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
            [manager.requestSerializer setValue:authorizationHeader forHTTPHeaderField:@"Authorization"];
            [manager.requestSerializer setValue:@"application/json" forHTTPHeaderField:@"content-type"];
            manager.responseSerializer = [AFJSONResponseSerializer serializer];
            
            [manager GET:serverURL parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
                //解析返回的JSON数据
                NSData *responseData = [NSJSONSerialization dataWithJSONObject:responseObject options:NSJSONWritingPrettyPrinted error:nil];
                NSArray *result = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingMutableLeaves error:nil];
                docPlist = [NSMutableArray arrayWithArray:result];
                //写入文件
                [docPlist writeToFile:plistPath atomically:YES];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSString *info = [NSString stringWithFormat:@"Error:获取最新用户组人员信息失败错误.%@",error.description];
                [self newLogWithInfo:info time:[NSDate date]];
            }];
        }
    });
}

#pragma mark - Add log info to plist
- (void)newLogWithInfo:(NSString *)info time:(NSDate *)currentDate
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
        NSString *userName   = [userDefaults objectForKey:kUserName];
        NSString *deviceUUID = [userDefaults objectForKey:kDeviceInfo];
        NSString *plistPath  = [userDefaults objectForKey:kPlistPath];
        NSDictionary *logDic = [NSDictionary dictionaryWithObjectsAndKeys:userName,kUserName,deviceUUID,kDeviceInfo,currentDate,kLogTime,info,kLogInfo, nil];
        NSMutableDictionary *docPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
        if (!docPlist) {
            docPlist = [NSMutableDictionary dictionary];
        }
        [docPlist setObject:logDic forKey:[NSString stringWithFormat:@"%@",currentDate]];
        //写入文件
        [docPlist writeToFile:plistPath atomically:YES];
    });
}

#pragma mark - Submit log to server
- (void)submitLogInfoToServer
{
    NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
    NSString *plistPath = [userDefaults objectForKey:kPlistPath];
    
    // 将Plist日志内容存入词典docPlist中
    NSMutableDictionary *docPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
    // 日志词典中存在日志，则发送日志到服务器中
    if ([docPlist count] > 0) {
        // 清空Plist日志内容
        NSDictionary *nullDic  = [NSDictionary dictionary];
        [nullDic writeToFile:plistPath atomically:YES];
        
        NSString *submitLogURL = [NSString stringWithFormat:@"%@api/",kBaseURL];
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer.acceptableContentTypes = [NSSet setWithObject:@"text/html"];
        manager.requestSerializer  = [AFHTTPRequestSerializer  serializer];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        NSEnumerator *enumerator = [docPlist keyEnumerator];
        id key;
        while ((key = [enumerator nextObject])) {
            /* code that uses the returned key */
            NSDictionary *para = [docPlist objectForKey:key];
            // 网络访问是异步的,回调是主线程的,因此程序员不用管在主线程更新UI的事情
            [manager POST:submitLogURL parameters:para success:^(AFHTTPRequestOperation *operation, id responseObject) {
                [docPlist removeObjectForKey:key];
            } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                NSString *info = [NSString stringWithFormat:@"Error:日志信息提交失败错误.%@",error.description];
                [self newLogWithInfo:info time:[NSDate date]];
            }];
        }
        // 发送失败的重新存入Plist文件中
        if ([docPlist count] > 0) {
            NSMutableDictionary *newPlist = [[NSMutableDictionary alloc] initWithContentsOfFile:plistPath];
            if (!newPlist) {
                newPlist = [NSMutableDictionary dictionary];
            }
            for (NSDictionary *logDic in newPlist) {
                [docPlist setObject:logDic forKey:[NSString stringWithFormat:@"%@",[logDic objectForKey:kLogTime]]];
                //写入文件
                [docPlist writeToFile:plistPath atomically:YES];
            }
        }
    }
}

@end
