//
//  MicrophoneAudioExample.m
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/11/24.
//

#import "MicrophoneAudioExample.h"
#import "MicrophoneAudioControlView.h"

@interface MicrophoneAudioExample () <QNRTCClientDelegate, QNMicrophoneAudioTrackDataDelegate, QNRemoteTrackAudioDataDelegate>

@property (nonatomic, strong) QNRTCClient *client;
@property (nonatomic, strong) QNMicrophoneAudioTrack *microphoneAudioTrack;
@property (nonatomic, strong) QNRemoteAudioTrack *remoteAudioTrack;
@property (nonatomic, strong) MicrophoneAudioControlView *controlView;
@property (nonatomic, copy) NSString *remoteUserID;

@end

@implementation MicrophoneAudioExample

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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
    self.localView.text = @"本地音频 Track";
    self.localView.hidden = YES;
    self.remoteView.text = @"远端音频 Track";
    self.remoteView.hidden = YES;
    self.tips = @"Tips：本示例仅展示一对一场景下 SDK 内置麦克风采集音频 Track 的发布和订阅，以及基于音频 Track 的相关功能。";
    
    // 添加音量控制视图
    self.controlView = [[[NSBundle mainBundle] loadNibNamed:@"MicrophoneAudioControlView" owner:nil options:nil] lastObject];
    [self.controlView.localVolumeSlider addTarget:self action:@selector(localVolumeSliderAction:) forControlEvents:UIControlEventValueChanged];
    [self.controlView.remoteVolumeSlider addTarget:self action:@selector(remoteVolumeSliderAction:) forControlEvents:UIControlEventValueChanged];
    [self.controlScrollView addSubview:self.controlView];
    [self.controlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.controlScrollView);
        make.width.mas_equalTo(SCREEN_WIDTH);
        make.height.mas_equalTo(200);
    }];
    [self.controlView layoutIfNeeded];
    self.controlScrollView.contentSize = self.controlView.frame.size;
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
    
    // 创建麦克风音频配置
    QNMicrophoneAudioTrackConfig *microphoneAudioTrackConfig = [[QNMicrophoneAudioTrackConfig alloc] initWithTag:@"micro" bitrate:64];
      
    if (microphoneAudioTrackConfig) {
        // 使用自定义配置创建麦克风音频 Track
        self.microphoneAudioTrack = [QNRTC createMicrophoneAudioTrackWithConfig:microphoneAudioTrackConfig];
    } else {
        // 也可以使用默认配置
        self.microphoneAudioTrack = [QNRTC createMicrophoneAudioTrack];
    }
    
    // 设置回调代理
    self.microphoneAudioTrack.audioDelegate = self;

    // 加入房间
    [self.client join:ROOM_TOKEN];
}

/*!
 * @abstract 发布 Track
 */
- (void)publish {
    __weak MicrophoneAudioExample *weakSelf = self;
    [self.client publish:@[self.microphoneAudioTrack] completeCallback:^(BOOL onPublished, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (onPublished) {
                [weakSelf showAlertWithTitle:@"房间状态" message:@"发布成功"];
                weakSelf.localView.hidden = NO;
            } else {
                [weakSelf showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"发布失败: %@", error.localizedDescription]];
            }
        });
    }];
}

#pragma mark - 音频 Track 音量设置
- (void)localVolumeSliderAction:(UISlider *)slider {
    [self.microphoneAudioTrack setVolume:slider.value];
}

- (void)remoteVolumeSliderAction:(UISlider *)slider {
    [self.remoteAudioTrack setVolume:slider.value * 10];
}

#pragma mark - QNMicrophoneAudioTrackDataDelegate
/*!
 * @abstract 本地麦克风音频 Track 数据回调。
 */
- (void)microphoneAudioTrack:(QNMicrophoneAudioTrack *)microphoneAudioTrack didGetAudioBuffer:(AudioBuffer *)audioBuffer bitsPerSample:(NSUInteger)bitsPerSample sampleRate:(NSUInteger)sampleRate {
    // 可以在此回调处理本地麦克风采集的原始音频数据
}

#pragma mark - QNRemoteTrackAudioDataDelegate
/*!
 * @abstract 远端音频 Track 数据回调。
 */
- (void)remoteAudioTrack:(QNRemoteAudioTrack *)remoteAudioTrack didGetAudioBuffer:(AudioBuffer *)audioBuffer bitsPerSample:(NSUInteger)bitsPerSample sampleRate:(NSUInteger)sampleRate {
    // 可以在此回调处理远端原始音频数据
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
            // 空闲状态  此时应查看回调 info 的具体信息做进一步处理
            switch (info.reason) {
                case QNConnectionDisconnectedReasonKickedOut: {
                    [self showAlertWithTitle:@"房间状态" message:@"已离开房间：被踢出房间" cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                case QNConnectionDisconnectedReasonLeave: {
                    [self showAlertWithTitle:@"房间状态" message:@"已离开房间：主动离开房间" cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                case QNConnectionDisconnectedReasonRoomClosed: {
                    [self showAlertWithTitle:@"房间状态" message:@"已离开房间：房间已关闭" cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                case QNConnectionDisconnectedReasonRoomFull: {
                    [self showAlertWithTitle:@"房间状态" message:@"已离开房间：房间人数已满" cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                case QNConnectionDisconnectedReasonError: {
                    NSString *errorMessage = info.error.localizedDescription;
                    if (info.error.code == QNRTCErrorReconnectTokenError) {
                        errorMessage = @"重新进入房间超时";
                    }
                    [self showAlertWithTitle:@"房间状态" message:[NSString stringWithFormat:@"已离开房间：%@", errorMessage] cancelAction:^{
                        [self.navigationController popViewControllerAnimated:YES];
                    }];
                }
                    break;
                default:
                    break;
            }
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
 * @abstract 订阅远端用户成功的回调。
 *
 * @since v4.0.0
 */
- (void)RTCClient:(QNRTCClient *)client didSubscribedRemoteVideoTracks:(NSArray<QNRemoteVideoTrack *> *)videoTracks audioTracks:(NSArray<QNRemoteAudioTrack *> *)audioTracks ofUserID:(NSString *)userID {
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([self.remoteUserID isEqualToString:userID]) {
            BOOL hasAudioTrack = NO;
            for (QNRemoteAudioTrack *track in audioTracks) {
                self.remoteAudioTrack = (QNRemoteAudioTrack *)track;
                self.remoteAudioTrack.audioDelegate = self;
                hasAudioTrack = YES;
                break;
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
