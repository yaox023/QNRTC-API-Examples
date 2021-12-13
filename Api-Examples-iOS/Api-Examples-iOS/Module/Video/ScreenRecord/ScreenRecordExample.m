//
//  ScreenRecordExample.m
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/11/24.
//

#import "ScreenRecordExample.h"
#import "ScreenRecordAnimationView.h"

@interface ScreenRecordExample () <QNRTCClientDelegate, QNScreenVideoTrackDelegate>

@property (nonatomic, strong) ScreenRecordAnimationView *animationView;

@property (nonatomic, strong) QNRTCClient *client;
@property (nonatomic, strong) QNScreenVideoTrack *screenVideoTrack;
@property (nonatomic, strong) QNGLKView *localRenderView;
@property (nonatomic, strong) QNVideoView *remoteRenderView;
@property (nonatomic, copy) NSString *remoteUserID;

@end

@implementation ScreenRecordExample

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 判断屏幕录制功能是否可用  屏幕录制功能仅在 iOS 11 及以上版本可用
    if ([QNScreenVideoTrack isScreenRecorderAvailable]) {
        [self loadSubviews];
        [self initRTC];
    } else {
        [self showAlertWithTitle:@"录屏状态" message:@"屏幕录制功能仅在 iOS 11 及以上版本可用" cancelAction:^{
            [self.navigationController popViewControllerAnimated:YES];
        }];
    }
}

/*!
 * @abstract 释放 SDK 资源
 */
- (void)dealloc {
    // 离开房间  释放 client
    [self.client leave];
    self.client.delegate = nil;
    self.client = nil;
    
    // 清理配置
    [QNRTC deinit];
    
    // 停止播放动画
    [self.animationView stopAnimation];
}

/*!
 * @abstract 初始化视图
 */
- (void)loadSubviews {
    self.localView.text = @"录屏本端无预览";
    self.remoteView.text = @"远端视图";
    self.tipsView.text = @"Tips：本示例仅展示一对一场景下 SDK 内置录屏采集视频 Track 的发布和订阅功能。";
    
    // 初始化本地预览视图
    self.localRenderView = [[QNGLKView alloc] init];
    [self.localView addSubview:self.localRenderView];
    self.localRenderView.hidden = YES;
    [self.localRenderView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.localView);
    }];
    
    // 初始化远端渲染视图
    self.remoteRenderView = [[QNVideoView alloc] init];
    [self.remoteView addSubview:self.remoteRenderView];
    self.remoteRenderView.hidden = YES;
    [self.remoteRenderView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.remoteView);
    }];
    
    // 初始化 Animation View
    self.animationView = [[ScreenRecordAnimationView alloc] init];
    [self.controlScrollView addSubview:self.animationView];
    [self.animationView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.controlScrollView);
        make.width.mas_equalTo(SCREEN_WIDTH);
        make.height.mas_equalTo(SCREEN_WIDTH * 0.6);
    }];
    self.controlScrollView.contentSize = self.animationView.frame.size;
    
    // 开始播放动画
    [self.animationView startAnimation];
}

/*!
 * @abstract 初始化 RTC
 */
- (void)initRTC {
    
    // QNRTC 配置
    [QNRTC enableFileLogging];
    QNRTCConfiguration *configuration = [QNRTCConfiguration defaultConfiguration];
    [QNRTC configRTC:configuration];
    
    // 创建 client
    self.client = [QNRTC createRTCClient];
    self.client.delegate = self;
    
    // 创建录屏采集视频 Track 配置
    QNScreenVideoTrackConfig *screenVideoTrackConfig = [[QNScreenVideoTrackConfig alloc] initWithSourceTag:@"screen"
                                                                                                   bitrate:600
                                                                                           videoEncodeSize:CGSizeMake(480, 640)
                                                                                         multiStreamEnable:NO];
    
    if (screenVideoTrackConfig) {
        // 使用自定义配置创建录屏 Track
        self.screenVideoTrack = [QNRTC createScreenVideoTrackWithConfig:screenVideoTrackConfig];
    } else {
        // 也可以使用默认配置
        self.screenVideoTrack = [QNRTC createScreenVideoTrack];
    }
    
    // 设置采集帧率
    self.screenVideoTrack.screenRecorderFrameRate = 20;
    
    // 设置代理
    self.screenVideoTrack.screenDelegate = self;
    self.localRenderView.hidden = NO;

    // 加入房间
    [self.client join:ROOM_TOKEN];
}

/*!
 * @abstract 发布相机视频 Track
 */
- (void)publish {
    __weak ScreenRecordExample *weakSelf = self;
    [self.client publish:@[self.screenVideoTrack] completeCallback:^(BOOL onPublished, NSError *error) {
        if (onPublished) {
            [weakSelf showAlertWithTitle:@"房间状态" message:@"发布成功"];
        } else {
            [weakSelf showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"发布失败: %@", error.localizedDescription]];
        }
    }];
}

#pragma mark - QNScreenVideoTrackDelegate
/*!
 * @abstract 录屏运行过程中发生错误会通过该方法回调。
 */
- (void)screenVideoTrack:(QNScreenVideoTrack *)screenVideoTrack didFailWithError:(NSError *)error {
    [self showAlertWithTitle:@"录屏状态" message:error.localizedDescription];
}

#pragma mark - QNRTCClientDelegate
/*!
 * @abstract 房间状态变更的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didConnectionStateChanged:(QNConnectionState)state disconnectedInfo:(QNConnectionDisconnectedInfo *)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (state == QNConnectionStateConnected) {
            // 已加入房间
            [self showAlertWithTitle:@"房间状态" message:@"已加入房间"];
            [self publish];
        } else if (state == QNConnectionStateIdle) {
            // 空闲  此时应查看回调 info 的具体信息做进一步处理
            [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"已离开房间：%@", info.error.localizedDescription]];
        } else if (state == QNConnectionStateReconnecting) {
            // 重连中
            [self showAlertWithTitle:@"房间状态" message:@"重连中"];
        } else if (state == QNConnectionStateReconnected) {
            // 重连成功
            [self showAlertWithTitle:@"房间状态" message:@"重连成功"];
        }
    });
}

/*!
 * @abstract 远端用户加入房间的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didJoinOfUserID:(NSString *)userID userData:(NSString *)userData {
    // 示例仅支持一对一的通话，因此这里记录首次加入房间的远端 userID
    self.remoteUserID = self.remoteUserID ?: userID;
    [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"%@ 加入房间", userID]];
}

/*!
 * @abstract 远端用户离开房间的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didLeaveOfUserID:(NSString *)userID {
    // 重置 remoteUserID
    if ([self.remoteUserID isEqualToString:userID]) self.remoteUserID = nil;
    [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"%@ 离开房间", userID]];
}

/*!
 * @abstract 远端用户视频首帧解码后的回调。
 */
- (void)RTCClient:(QNRTCClient *)client firstVideoDidDecodeOfTrack:(QNRemoteVideoTrack *)videoTrack remoteUserID:(NSString *)userID {
    // 仅渲染当前加入房间的首个远端用户的视图
    if ([userID isEqualToString:self.remoteUserID]) {
        [videoTrack play:self.remoteRenderView];
        self.remoteRenderView.hidden = NO;
    }
}

/*!
 * @abstract 远端用户视频取消渲染到 renderView 上的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didDetachRenderTrack:(QNRemoteVideoTrack *)videoTrack remoteUserID:(NSString *)userID {
    // 移除当前渲染的远端用户的视图
    if ([userID isEqualToString:self.remoteUserID]) {
        [videoTrack play:nil];
        self.remoteRenderView.hidden = YES;
    }
}

@end
