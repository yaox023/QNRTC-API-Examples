//
//  TranscodingLiveCustomExample.m
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/12/9.
//

#import "TranscodingLiveCustomExample.h"
#import "TranscodingLiveCustomControlView.h"

@interface TranscodingLiveCustomExample () <QNRTCClientDelegate>

@property (nonatomic, strong) TranscodingLiveCustomControlView *controlView;

@property (nonatomic, strong) QNRTCClient *client;
@property (nonatomic, strong) QNCameraVideoTrack *cameraVideoTrack;
@property (nonatomic, strong) QNMicrophoneAudioTrack *microphoneAudioTrack;
@property (nonatomic, strong) QNGLKView *localRenderView;
@property (nonatomic, strong) QNVideoView *remoteRenderView;
@property (nonatomic, strong) QNTranscodingLiveStreamingConfig *transcodingLiveStreamingConfig;
@property (nonatomic, copy) NSString *remoteUserID;
@property (nonatomic, copy) NSString *streamID;
@property (nonatomic, assign) BOOL isStreaming;

@end

@implementation TranscodingLiveCustomExample

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    self.isStreaming = NO;
    self.streamID = [NSString stringWithFormat:@"%@-%@", self.roomName, self.userID];
    [self loadSubviews];
    [self initRTC];
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
}

/*!
 * @abstract 初始化视图
 */
- (void)loadSubviews {
    self.localView.text = @"本端视图";
    self.remoteView.text = @"远端视图";
    self.tipsView.text = @"Tips：\n"
    "1.本示例仅展示一对一场景下使用自定义合流配置创建合流转推的功能。\n"
    "2.使用转推功能需要在七牛后台开启对应 AppId 的转推功能开关。\n"
    "3.开启转推后即可用转推地址对应的拉流地址观看合流效果。";
    
    // 添加转推控制视图
    self.controlView = [[[NSBundle mainBundle] loadNibNamed:@"TranscodingLiveCustomControlView" owner:nil options:nil] lastObject];
    self.controlView.publishUrlTF.text = PUBLISH_URL;
    [self.controlView.startStreamingButton addTarget:self action:@selector(startStreamingButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.controlView.stopStreamingButton addTarget:self action:@selector(stopStreamingButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.controlView.addLayoutButton addTarget:self action:@selector(addLayoutButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.controlView.removeLayoutButton addTarget:self action:@selector(removeLayoutButtonAction) forControlEvents:UIControlEventTouchUpInside];
    [self.controlScrollView addSubview:self.controlView];
    [self.controlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.controlScrollView);
        make.width.mas_equalTo(SCREEN_WIDTH);
        make.height.mas_equalTo(1050);
    }];
    [self.controlView layoutIfNeeded];
    self.controlScrollView.contentSize = self.controlView.frame.size;
    
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
    
    // 自定义采集配置
    QNCameraVideoTrackConfig *cameraVideoTrackConfig = [[QNCameraVideoTrackConfig alloc] initWithSourceTag:@"camera"
                                                                                                   bitrate:1000
                                                                                           videoEncodeSize:CGSizeMake(720, 1280)
                                                                                         multiStreamEnable:NO];
    
    // 使用自定义配置创建相机采集视频 Track
    self.cameraVideoTrack = [QNRTC createCameraVideoTrackWithConfig:cameraVideoTrackConfig];
    
    // 设置采集分辨率（要保证预览分辨率 sessionPreset 不小于 QNCameraVideoTrackConfig 的编码分辨率 videoEncodeSize）
    self.cameraVideoTrack.sessionPreset = AVCaptureSessionPreset1280x720;
    
    // 创建麦克风采集音频 Track
    self.microphoneAudioTrack = [QNRTC createMicrophoneAudioTrack];
        
    // 开启本地预览
    [self.cameraVideoTrack play:self.localRenderView];
    self.localRenderView.hidden = NO;

    // 加入房间
    [self.client join:ROOM_TOKEN];
}

/*!
 * @abstract 发布
 */
- (void)publish {
    __weak TranscodingLiveCustomExample *weakSelf = self;
    [self.client publish:@[self.cameraVideoTrack, self.microphoneAudioTrack] completeCallback:^(BOOL onPublished, NSError *error) {
        if (onPublished) {
            [weakSelf showAlertWithTitle:@"房间状态" message:@"发布成功"];
        } else {
            [weakSelf showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"发布失败: %@", error.localizedDescription]];
        }
    }];
}

#pragma mark - 转推相关操作、QNRTCClientDelegate 中转推相关的回调
/*!
 * @abstract 点击开启自定义合流转推
 */
- (void)startStreamingButtonAction {
    // 校验是否在转推中
    if (self.isStreaming) {
        [self showAlertWithTitle:@"状态提示" message:@"请先停止转推任务"];
        return;
    }
    
    // 校验转推地址
    if ([self.controlView.publishUrlTF.text isEqualToString:@""]) {
        [self showAlertWithTitle:@"参数错误" message:@"请输入转推地址"];
        return;
    }
    
    // 校验房间状态
    if (!(self.client.roomState == QNConnectionStateConnected || self.client.roomState == QNConnectionStateReconnected)) {
        [self showAlertWithTitle:@"状态提示" message:@"请先加入房间"];
        return;
    }
    
    // 创建自定义转推配置
    self.transcodingLiveStreamingConfig = [[QNTranscodingLiveStreamingConfig alloc] init];
    
    // 转推地址
    self.transcodingLiveStreamingConfig.publishUrl = self.controlView.publishUrlTF.text;
    // 转推任务标识符 - 房间内保持唯一
    self.transcodingLiveStreamingConfig.streamID = self.streamID;
    // 合流整体画面的宽
    self.transcodingLiveStreamingConfig.width = self.controlView.streamWidthTF.text.intValue;
    // 合流整体画面的高
    self.transcodingLiveStreamingConfig.height = self.controlView.streamHeightTF.text.intValue;
    // 合流帧率
    self.transcodingLiveStreamingConfig.fps = self.controlView.streamFpsTF.text.intValue;
    // 合流码率
    self.transcodingLiveStreamingConfig.bitrateBps = self.controlView.streamBpsTF.text.intValue * 1000;
    // 合流最大码率
    self.transcodingLiveStreamingConfig.maxBitrateBps = self.transcodingLiveStreamingConfig.bitrateBps;
    // 合流最小码率
    self.transcodingLiveStreamingConfig.minBitrateBps = self.transcodingLiveStreamingConfig.bitrateBps;
    // 合流保持最后一帧
    self.transcodingLiveStreamingConfig.holdLastFrame = NO;
    
    // 填充模式
    QNVideoFillModeType fillMode = QNVideoFillModePreserveAspectRatioAndFill;
    RadioButton *selectedFillMode = self.controlView.aspectFitButton.selectedButton;
    if (selectedFillMode == self.controlView.aspectFillButton) {
        fillMode = QNVideoFillModePreserveAspectRatioAndFill;
    } else if (selectedFillMode == self.controlView.aspectFitButton) {
        fillMode = QNVideoFillModePreserveAspectRatio;
    } else if (selectedFillMode == self.controlView.scaleFitButton) {
        fillMode = QNVideoFillModeStretch;
    }
    self.transcodingLiveStreamingConfig.fillMode = fillMode;
    
    // 合流水印
    if (self.controlView.watermarkSwitch.isOn) {
        QNTranscodingLiveStreamingImage *watermarkImage = [[QNTranscodingLiveStreamingImage alloc] init];
        watermarkImage.imageUrl = @"http://pili-playback.qnsdk.com/qiniu-logo-110-34.png";
        watermarkImage.frame = CGRectMake(30, 40, 110, 34);
        self.transcodingLiveStreamingConfig.watermarks = @[watermarkImage];
    }
    
    // 合流背景图
    if (self.controlView.bgImageSwitch.isOn) {
        QNTranscodingLiveStreamingImage *backgroundImage = [[QNTranscodingLiveStreamingImage alloc] init];
        backgroundImage.imageUrl = @"http://pili-playback.qnsdk.com/ivs_background_1280x720.png";
        backgroundImage.frame = CGRectMake(0, 0, self.transcodingLiveStreamingConfig.width, self.transcodingLiveStreamingConfig.height);
        self.transcodingLiveStreamingConfig.background = backgroundImage;
    }
    
    // 开启合流转推
    [self.client startLiveStreamingWithTranscoding:self.transcodingLiveStreamingConfig];
}

/*!
 * @abstract 点击停止自定义合流转推
 */
- (void)stopStreamingButtonAction {
    // 校验房间状态
    if (!(self.client.roomState == QNConnectionStateConnected || self.client.roomState == QNConnectionStateReconnected)) {
        [self showAlertWithTitle:@"状态提示" message:@"请先加入房间"];
        return;
    }
    
    // 停止合流转推
    [self.client stopLiveStreamingWithTranscoding:self.transcodingLiveStreamingConfig];
}

/*!
 * @abstract 点击添加本地 / 远端音视频 Track 合流布局
 */
- (void)addLayoutButtonAction {
    // 校验房间状态
    if (!(self.client.roomState == QNConnectionStateConnected || self.client.roomState == QNConnectionStateReconnected)) {
        [self showAlertWithTitle:@"状态提示" message:@"请先加入房间"];
        return;
    }
    
    NSString *videoStreamingTrackID, *audioStreamingTrackID = nil;
    BOOL isLocalUser = (self.controlView.localUserButton.selectedButton == self.controlView.localUserButton);
    if (isLocalUser) {
        videoStreamingTrackID = self.cameraVideoTrack.trackID;
        audioStreamingTrackID = self.microphoneAudioTrack.trackID;
    } else {
        if (self.remoteUserID) {
            QNRemoteUser *remoteUser = [self.client getRemoteUser:self.remoteUserID];
            // 这里去远端用户音视频数组里的第一个 Track 用于合流
            videoStreamingTrackID = remoteUser.videoTrack.firstObject.trackID;
            audioStreamingTrackID = remoteUser.audioTrack.firstObject.trackID;
        } else {
            [self showAlertWithTitle:@"状态提示" message:@"没有远端用户加入"];
            return;
        }
    }
    
    // 视频 Track 合流布局配置
    QNTranscodingLiveStreamingTrack *videoStreamingTrack = [[QNTranscodingLiveStreamingTrack alloc] init];
    videoStreamingTrack.trackId = videoStreamingTrackID;
    videoStreamingTrack.zIndex = self.controlView.layoutZTF.text.intValue;
    videoStreamingTrack.frame = CGRectMake(self.controlView.layoutXTF.text.intValue,
                                                     self.controlView.layoutYTF.text.intValue,
                                                     self.controlView.layoutWidthTF.text.intValue,
                                                     self.controlView.layoutHeightTF.text.intValue);
    
    // 音频 Track 合流布局配置
    QNTranscodingLiveStreamingTrack *audioStreamingTrack = [[QNTranscodingLiveStreamingTrack alloc] init];
    // 音频只需指定 Track ID
    audioStreamingTrack.trackId = audioStreamingTrackID;
    
    // 添加合流布局
    [self.client setTranscodingLiveStreamingID:self.streamID withTracks:@[videoStreamingTrack, audioStreamingTrack]];
}

/*!
 * @abstract 点击移除合流布局
 */
- (void)removeLayoutButtonAction {
    // 校验房间状态
    if (!(self.client.roomState == QNConnectionStateConnected || self.client.roomState == QNConnectionStateReconnected)) {
        [self showAlertWithTitle:@"状态提示" message:@"请先加入房间"];
        return;
    }
    
    NSString *videoStreamingTrackID, *audioStreamingTrackID = nil;
    BOOL isLocalUser = (self.controlView.localUserButton.selectedButton == self.controlView.localUserButton);
    if (isLocalUser) {
        videoStreamingTrackID = self.cameraVideoTrack.trackID;
        audioStreamingTrackID = self.microphoneAudioTrack.trackID;
    } else {
        if (self.remoteUserID) {
            QNRemoteUser *remoteUser = [self.client getRemoteUser:self.remoteUserID];
            // 这里去远端用户音视频数组里的第一个 Track 用于合流
            videoStreamingTrackID = remoteUser.videoTrack.firstObject.trackID;
            audioStreamingTrackID = remoteUser.audioTrack.firstObject.trackID;
        } else {
            [self showAlertWithTitle:@"状态提示" message:@"没有远端用户加入"];
            return;
        }
    }
    
    // 创建视频合流布局配置，只需指定 Track ID，用于移除
    QNTranscodingLiveStreamingTrack *videoStreamingTrack = [[QNTranscodingLiveStreamingTrack alloc] init];
    videoStreamingTrack.trackId = videoStreamingTrackID;
    
    // 创建音频合流布局配置，只需指定 Track ID，用于移除
    QNTranscodingLiveStreamingTrack *audioStreamingTrack = [[QNTranscodingLiveStreamingTrack alloc] init];
    audioStreamingTrack.trackId = audioStreamingTrackID;

    // 移除合流布局（这里的 Tracks 数组也可传入添加合流布局时使用的布局配置数组，保证 trackId 有效即可）
    [self.client removeTranscodingLiveStreamingID:self.streamID withTracks:@[videoStreamingTrack, audioStreamingTrack]];
}

/*!
 * @abstract 成功创建合流转推任务的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didStartLiveStreamingWith:(NSString *)streamID {
    self.isStreaming = YES;
    [self showAlertWithTitle:@"转推状态" message:@"创建合流转推成功"];
}

/*!
 * @abstract 停止合流转推任务的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didStopLiveStreamingWith:(NSString *)streamID {
    self.isStreaming = NO;
    [self showAlertWithTitle:@"转推状态" message:@"停止合流转推成功"];
}

/*!
 * @abstract 更新合流布局的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didTranscodingTracksUpdated:(BOOL)success withStreamID:(NSString *)streamID {
    [self showAlertWithTitle:@"转推状态" message:@"更新合流布局成功"];
}

/*!
 * @abstract 合流转推出错的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didErrorLiveStreamingWith:(NSString *)streamID errorInfo:(QNLiveStreamingErrorInfo *)errorInfo {
    NSString *errorType = @"";
    switch (errorInfo.type) {
        case QNLiveStreamingTypeStart: errorType = @"QNLiveStreamingTypeStart"; break;
        case QNLiveStreamingTypeStop: errorType = @"QNLiveStreamingTypeStop"; break;
        case QNLiveStreamingTypeUpdate: errorType = @"QNLiveStreamingTypeUpdate"; break;
        default: break;
    }
    NSString *errorDesc = [NSString stringWithFormat:@"Error Type: %@\nError Desc: %@", errorType, errorInfo.error.localizedDescription];
    [self showAlertWithTitle:@"转推出错" message:errorDesc cancelAction:nil];
}

#pragma mark - QNRTCClientDelegate 中其他回调
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
