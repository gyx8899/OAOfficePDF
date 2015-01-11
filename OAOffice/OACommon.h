//
//  OACommon.h
//  OAOffice
//
//  Created by admin on 15/1/5.
//  Copyright (c) 2015年 DigitalOcean. All rights reserved.
//

#ifndef OAOffice_OACommon_h
#define OAOffice_OACommon_h

//随机颜色

#define MJRandomColor [UIColor colorWithRed:arc4random_uniform(255)/255.0 green:arc4random_uniform(255)/255.0 blue:arc4random_uniform(255)/255.0 alpha:1]

// 2.日志输出宏定义
#ifdef DEBUG
// 调试状态
#define MyLog(...) NSLog(__VA_ARGS__)
#else
// 发布状态
#define MyLog(...)
#endif

#define kUserName           @"userName"
#define kPassword           @"password"
#define kReachable          @"reachable"
#define kNewUser            @"newUser"
#define kAuthorizationHeader @"AuthorizationHeader"

#define kOAPDFDocument      @"ReaderDocument"
#define kOADocumentFolder   @"DocumentFolder"

#define kFileName           @"fileName"
#define kFilePath           @"filePath"
#define kFileURL            @"fileURL"
#define kFilePassword       @"password"
#define kFileSize           @"fileSize"
#define kFileDate           @"fileDate"
#define kFileTag            @"fileTag"
#define kFileGuid           @"guid"
#define kFilePageNumber     @"pageNumber"
#define kFileLastOpen       @"lastOpen"
#define kFileThumbImage     @"thumbImage"
#define kTaskStartTime      @"taskStartTime"

#define kOAPDFCellHeight    244.0f
#define kOAPDFCellWidth     192.0f
#define kOAPDFCellTitleHeight 40.0f
#define kTagViewHeight      68.0f
#define kTagViewWidth       65.0f

#define kThemeColor         [UIColor colorWithRed:0.f green:166.f/255.f blue:240.f/255.f alpha:1.f] //#00a6f0
#define kPDFThumbBGColor    [UIColor colorWithRed:1.f green:1.f blue:1.f alpha:0.5f]

#define kLABEL_HEIGHT       20.0f
#define kCellHeaderHeight   30.0f

//#define kUserURL            @"http://192.168.182.4:80/api/pad/getUser"
//#define kTaskURL            @"http://192.168.182.4:80/api/getTasks/"
//#define kBaseURL            @"http://192.168.182.4:80/"

//#define kUserURL            @"http://192.168.69.242:80/api/pad/getUser"
//#define kTaskURL            @"http://192.168.69.242:80/api/getTasks/"
//#define kBaseURL            @"http://192.168.69.242:80/"

#define kUserURL            @"http://101.231.140.106:8080/api/pad/getUser"
#define kTaskURL            @"http://101.231.140.106:8080/api/getTasks/"
#define kBaseURL            @"http://101.231.140.106:8080/"

#define kDocumentPath       [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0]

#define kNetConnect         @"netConnect"
#define kPlistPath          @"plistPath"
#define kUserPlist          @"userPlist"
#define kInfoPlist          @"infoPlist"
#define kDeviceInfo         @"deviceInfo"
#define kLogTime            @"logTime"
#define kLogInfo            @"logInfo"
#define kTimeout            5
#define kESignImage         @"signImg"
#define kName               @"Name"

#define kOADoneMissive      @"DoneMissive"
#define kTaskId             @"taskId"
#define kTaskName           @"taskName"
#define kMissiveTitle       @"missiveTitle"
#define kMissiveDoneTime    @"missiveDoneTime"
#define kMissiveAddr        @"missiveAddr"
#define kUrgentLevel        @"urgentLevel"

#define kPageSize           15

#define kLogErrorType       @"error"
#define kLogInfoType        @"info"
#define kLogType            @"type"

#endif
