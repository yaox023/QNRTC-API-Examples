//
//  AudioMixExample.m
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/11/24.
//

#import "AudioMixExample.h"
#import "AudioMixControlView.h"

@interface AudioMixExample () <QNRTCClientDelegate, QNAudioMixerDelegate>

@property (nonatomic, strong) AudioMixControlView *controlView;

@property (nonatomic, strong) QNRTCClient *client;
@property (nonatomic, strong) QNMicrophoneAudioTrack *microphoneAudioTrack;
@property (nonatomic, strong) QNRemoteAudioTrack *remoteAudioTrack;
@property (nonatomic, copy) NSString *remoteUserID;

@end

@implementation AudioMixExample

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
    self.tipsView.text = @"Tips：本示例仅展示一对一场景下的麦克风音频的发布和订阅，以及麦克风音频 Track 的混音功能。";
    
    // 混音控制面板
    self.controlView = [[[NSBundle mainBundle] loadNibNamed:@"AudioMixControlView" owner:nil options:nil] lastObject];
    self.controlView.musicUrlTF.text = [[NSBundle mainBundle] pathForResource:@"Pursue" ofType:@"mp3"];
    [self.controlView.playStopButton setTitle:@"Play" forState:UIControlStateNormal];
    [self.controlView.playStopButton setTitle:@"Stop" forState:UIControlStateSelected];
    [self.controlView.resumePauseButton setTitle:@"Pause" forState:UIControlStateNormal];
    [self.controlView.resumePauseButton setTitle:@"Resume" forState:UIControlStateSelected];
    [self.controlView.currentTimeSlider addTarget:self action:@selector(currentTimeSliderAction:) forControlEvents:UIControlEventValueChanged];
    [self.controlView.micInputVolumeSlider addTarget:self action:@selector(micInputVolumeSliderAction:) forControlEvents:UIControlEventValueChanged];
    [self.controlView.musicInputVolumeSlider addTarget:self action:@selector(musicInputVolumeSliderAction:) forControlEvents:UIControlEventValueChanged];
    [self.controlView.musicPlayVolumeSlider addTarget:self action:@selector(musicPlayVolumeSliderAction:) forControlEvents:UIControlEventValueChanged];
    [self.controlView.playStopButton addTarget:self action:@selector(playStopButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.controlView.resumePauseButton addTarget:self action:@selector(resumePauseButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.controlView.playbackSwitch addTarget:self action:@selector(playbackSwitchAction:) forControlEvents:UIControlEventValueChanged];
    
    [self.controlScrollView addSubview:self.controlView];
    [self.controlView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.controlScrollView);
        make.width.mas_equalTo(SCREEN_WIDTH);
        make.height.mas_equalTo(400);
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
    
    // 可以使用默认配置创建麦克风音频 Track
    self.microphoneAudioTrack = [QNRTC createMicrophoneAudioTrack];
    
    // 设置混音回调代理
    self.client.audioMixer.delegate = self;
    // 手动设置混音进度回调间隔，默认为 0 不回调
    self.client.audioMixer.rateInterval = 1;
    // 设置麦克风输入音量
    self.client.audioMixer.microphoneInputVolume = 0.5;
    // 设置音频输入音量
    self.client.audioMixer.musicInputVolume = 0.5;
    // 设置音频播放音量
    self.client.audioMixer.musicOutputVolume = 0.5;
    // 设置返听
    self.client.audioMixer.playBack = NO;
    
    // 加入房间
    [self.client join:ROOM_TOKEN];
}

/*!
 * @abstract 发布 Track
 */
- (void)publish {
    __weak AudioMixExample *weakSelf = self;
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

#pragma mark - 混音面板控制事件
/**
 * 拖拽进度条，在拖拽结束调用 seekTo
 */
- (void)currentTimeSliderAction:(UISlider *)slider {
    [self.client.audioMixer seekTo:CMTimeMakeWithSeconds(slider.value * self.client.audioMixer.duration, 1000)];
}

/**
 * 拖拽进度条，设置混音时麦克风的输入音量
 */
- (void)micInputVolumeSliderAction:(UISlider *)slider {
    self.client.audioMixer.microphoneInputVolume = slider.value;
}

/**
 * 拖拽进度条，设置混音时音频文件的输入音量
 */
- (void)musicInputVolumeSliderAction:(UISlider *)slider {
    self.client.audioMixer.musicInputVolume = slider.value;
}

/**
 * 拖拽进度条，设置混音时音频文件的实时播放音量
 */
- (void)musicPlayVolumeSliderAction:(UISlider *)slider {
    self.client.audioMixer.musicOutputVolume = slider.value;
}

/**
 * 点击开始/停止混音
 */
- (void)playStopButtonAction:(UIButton *)button {
    if (!button.isSelected) {
        self.client.audioMixer.audioURL = [NSURL URLWithString:self.controlView.musicUrlTF.text];
        [self.client.audioMixer start:[self.controlView.loopTimeTF.text integerValue]];
    } else {
        [self.client.audioMixer stop];
    }
}

/**
 * 点击继续/暂停混音
 */
- (void)resumePauseButtonAction:(UIButton *)button {
    if (!button.isSelected) {
        [self.client.audioMixer pause];
    } else {
        [self.client.audioMixer resume];
    }
}

- (void)playbackSwitchAction:(UISwitch *)switcher {
    self.client.audioMixer.playBack = switcher.isOn;
}

#pragma mark - QNAudioMixerDelegate
/**
 * QNAudioMixer 在运行过程中，发生错误的回调
 */
- (void)audioMixer:(QNAudioMixer *)audioMixer didFailWithError:(NSError *)error {
    [self showAlertWithTitle:@"混音错误" message:error.localizedDescription];
}

/**
 * QNAudioMixer 在运行过程中，音频状态发生变化的回调
 */
- (void)audioMixer:(QNAudioMixer *)audioMixer playStateDidChange:(QNAudioPlayState)playState {
    NSString *playStateDes = @"";
    switch (playState) {
        case QNAudioPlayStateInit: playStateDes = @"初始状态";  break;
        case QNAudioPlayStateReady: playStateDes = @"准备播放"; break;
        case QNAudioPlayStatePlaying: playStateDes = @"正在播放"; break;
        case QNAudioPlayStateBuffering: playStateDes = @"数据缓冲"; break;
        case QNAudioPlayStatePaused: playStateDes = @"暂停播放"; break;
        case QNAudioPlayStateStoped: playStateDes = @"停止播放"; break;
        case QNAudioPlayStateCompleted: playStateDes = @"播放完成"; break;
        case QNAudioPlayStateError:  playStateDes = @"播放发生错误"; break;
        case QNAudioPlayStateUnknow: playStateDes = @"播放发生未知错误"; break;
        default: break;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (playState == QNAudioPlayStatePaused) {
            self.controlView.resumePauseButton.selected = YES;
        } else {
            self.controlView.resumePauseButton.selected = NO;
        }
        
        if (playState == QNAudioPlayStateInit
            || playState == QNAudioPlayStateStoped
            || playState == QNAudioPlayStateCompleted
            || playState == QNAudioPlayStateError
            || playState == QNAudioPlayStateUnknow) {
            
            self.controlView.playStopButton.selected = NO;
            self.controlView.currentTimeLabel.text = @"0:00 / x:xx";
            self.controlView.currentTimeSlider.value = 0;
        } else {
            self.controlView.playStopButton.selected = YES;
        }
    });
    
    
    [self showAlertWithTitle:@"混音状态" message:playStateDes];
}

/**
 * QNAudioMixer 在运行过程中，混音进度的回调
 */
- (void)audioMixer:(QNAudioMixer *)audioMixer didMixing:(NSTimeInterval)currentTime {
    dispatch_async(dispatch_get_main_queue(), ^{
        // 更新进度 label
        NSInteger durationSeconds = (NSInteger)audioMixer.duration % 60;
        NSInteger durationMinites = (NSInteger)audioMixer.duration / 60;
        NSInteger currentSeconds = (NSInteger)currentTime % 60;
        NSInteger currentMinites = (NSInteger)currentTime / 60;
        NSString *currentTimeDesc = [NSString stringWithFormat:@"%02ld:%02ld / %02ld:%02ld", currentMinites, currentSeconds, durationMinites, durationSeconds];
        self.controlView.currentTimeLabel.text = currentTimeDesc;
        
        // 更新进度 slider
        self.controlView.currentTimeSlider.value = currentTime / audioMixer.duration;
    });
}

/**
 * QNAudioMixer 在运行过程中，麦克风音频数据的回调
 */
- (void)audioMixer:(QNAudioMixer *)audioMixer microphoneSourceDidGetAudioBuffer:(AudioBuffer *)audioBuffer asbd:(const AudioStreamBasicDescription *)asbd {
    // 在这里处理麦克风采集原始数据
}

/**
 * QNAudioMixer 在运行过程中，音乐音频数据的回调
 */
- (void)audioMixer:(QNAudioMixer *)audioMixer musicSourceDidGetAudioBuffer:(AudioBuffer *)audioBuffer asbd:(const AudioStreamBasicDescription *)asbd {
    // 在这里处理音频文件输入原始数据
}

/**
 * QNAudioMixer 在运行过程中，混音数据的回调
 */
- (void)audioMixer:(QNAudioMixer *)audioMixer mixedSourceDidGetAudioBuffer:(AudioBuffer *)audioBuffer asbd:(const AudioStreamBasicDescription *)asbd {
    // 在这里处理混音后的音频原始数据
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
