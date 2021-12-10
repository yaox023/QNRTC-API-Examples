//
//  CustomAudioExample.m
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/11/24.
//

#import "CustomAudioExample.h"
#import "CustomAudioSource.h"

@interface CustomAudioExample () <QNRTCClientDelegate, CustomAudioSourceDelegate>

@property (nonatomic, strong) CustomAudioSource *audioSource;

@property (nonatomic, strong) QNRTCClient *client;
@property (nonatomic, strong) QNCustomAudioTrack *customAudioTrack;
@property (nonatomic, strong) QNRemoteAudioTrack *remoteAudioTrack;
@property (nonatomic, copy) NSString *remoteUserID;

@end

@implementation CustomAudioExample

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self loadSubviews];
    [self initAudioSource];
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
    
    // 停止采集
    [self.audioSource stopCaptureSession];
}

/*!
 * @abstract 初始化视图
 */
- (void)loadSubviews {
    self.localView.text = @"本地音频 Track";
    self.localView.hidden = YES;
    self.remoteView.text = @"远端音频 Track";
    self.remoteView.hidden = YES;
    self.tipsView.text = @"Tips：本示例仅展示一对一场景下自定义音频采集 Track 的发布和订阅功能";
}

/*!
 * @abstract 初始化自定义采集模块
 */
- (void)initAudioSource {
    self.audioSource = [[CustomAudioSource alloc] init];
    self.audioSource.delegate = self;
    [self.audioSource startCaptureSession];
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
    
    // 创建自定义采集音频配置
    QNCustomAudioTrackConfig *customAudioTrackConfig = [[QNCustomAudioTrackConfig alloc] initWithTag:@"custom" bitrate:64];
      
    if (customAudioTrackConfig) {
        // 使用自定义配置创建自定义音频 Track
        self.customAudioTrack = [QNRTC createCustomAudioTrackWithConfig:customAudioTrackConfig];
    } else {
        // 也可以使用默认配置
        self.customAudioTrack = [QNRTC createCustomAudioTrack];
    }

    // 加入房间
    [self.client join:ROOM_TOKEN];
}

/*!
 * @abstract 发布 Track
 */
- (void)publish {
    [self.client publish:@[self.customAudioTrack] completeCallback:^(BOOL onPublished, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (onPublished) {
                [self showAlertWithTitle:@"房间状态" message:@"发布成功"];
                self.localView.hidden = NO;
            } else {
                [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"发布失败: %@", error.localizedDescription]];
            }
        });
    }];
}

#pragma mark - CustomAudioSourceDelegate
/*!
 * @abstract 自定义音频数据回调。
 */
- (void)customAudioSource:(CustomAudioSource *)audioSource didOutputAudioBufferList:(AudioBufferList *)audioBufferList {
    if (self.client.roomState == QNConnectionStateConnected || self.client.roomState == QNConnectionStateReconnected) {
        @autoreleasepool {
            AudioBuffer *buffer = &audioBufferList->mBuffers[0];
            AudioStreamBasicDescription asdb = [self.audioSource getASDB];
            [self.customAudioTrack pushAudioBuffer:buffer asbd:&asdb];
        }
    }
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
 * @abstract 远端用户发布音/视频的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didUserPublishTracks:(NSArray<QNRemoteTrack *> *)tracks ofUserID:(NSString *)userID {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.remoteUserID isEqualToString:userID]) {
            BOOL hasAudioTrack = NO;
            for (QNRemoteTrack *track in tracks) {
                if (track.kind == QNTrackKindAudio) {
                    self.remoteAudioTrack = (QNRemoteAudioTrack *)track;
                    hasAudioTrack = YES;
                    break;
                }
            }
            if (hasAudioTrack) {
                self.remoteView.hidden = NO;
            }
        }
    });
}

/*!
 * @abstract 远端用户取消发布音/视频的回调。
 */
- (void)RTCClient:(QNRTCClient *)client didUserUnpublishTracks:(NSArray<QNRemoteTrack *> *)tracks ofUserID:(NSString *)userID {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (QNRemoteTrack *track in tracks) {
            if ([track.trackID isEqualToString:self.remoteAudioTrack.trackID]) {
                self.remoteAudioTrack = nil;
                self.remoteView.hidden = YES;
                break;
            }
        }
    });
}

@end
