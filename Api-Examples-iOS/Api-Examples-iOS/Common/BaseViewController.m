//
//  BaseViewController.m
//  Api-Examples-iOS
//
//  Created by WorkSpace_Sun on 2021/11/24.
//

#import "BaseViewController.h"

@interface BaseViewController ()
@property (nonatomic, strong) dispatch_queue_t alertQueue;
@end

@implementation BaseViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor whiteColor];
    [self parseToken];
    [self loadBaseViews];
    self.alertQueue = dispatch_queue_create("com.api-examples.alert", DISPATCH_QUEUE_SERIAL);
}

- (void)loadBaseViews {
    CGFloat topMargin = [[UIApplication sharedApplication] statusBarFrame].size.height + 44.0;
    [self.localView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view);
        make.top.equalTo(self.view).mas_offset(topMargin);
        make.width.mas_equalTo(SCREEN_WIDTH / 2.0);
        make.height.mas_equalTo(SCREEN_WIDTH / 2.0 * 1.1);
    }];
    [self.remoteView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.view);
        make.top.equalTo(self.view).mas_offset(topMargin);
        make.width.mas_equalTo(SCREEN_WIDTH / 2.0);
        make.height.mas_equalTo(SCREEN_WIDTH / 2.0 * 1.1);
    }];
    [self.tipsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).mas_offset(30.0);
        make.right.equalTo(self.view).mas_offset(-30.0);
        make.bottom.equalTo(self.view).mas_offset(-30.0);
        make.height.mas_equalTo(120.0);
    }];
    [self.controlScrollView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.localView.mas_bottom).mas_offset(30);
        make.left.right.equalTo(self.view);
        make.bottom.equalTo(self.tipsView.mas_top).mas_offset(-30);
    }];
}

- (void)parseToken {
    BOOL isValid = NO;
    if (![ROOM_TOKEN isEqualToString:@""]) {
        NSArray *tokenParts = [ROOM_TOKEN componentsSeparatedByString:@":"];
        NSString *roomInfoBase64 = [tokenParts lastObject];
        NSData *roomInfoBase64Data = [[NSData alloc] initWithBase64EncodedString:roomInfoBase64 options:0];
        
        NSError *error;
        NSDictionary *roomInfoDic = [NSJSONSerialization JSONObjectWithData:roomInfoBase64Data options:NSJSONReadingAllowFragments error:&error];
        if (!error) {
            if (roomInfoDic[@"appId"] && roomInfoDic[@"roomName"] && roomInfoDic[@"userId"] && roomInfoDic[@"expireAt"]) {
                isValid =  YES;
                self.roomName = roomInfoDic[@"roomName"];
                self.userID = roomInfoDic[@"userId"];
            }
        }
    }
    if (!isValid) {
        [self showAlertWithTitle:@"提示" message:@"Token 检验失败" cancelAction:^{
            [self.navigationController popViewControllerAnimated:YES];
        }];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

-  (void)controlScrollViewDidTap {
    [self.view endEditing:YES];
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message {
    dispatch_async(self.alertQueue, ^{
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
            [self.navigationController presentViewController:alertController animated:YES completion:^{
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [alertController dismissViewControllerAnimated:NO completion:^{
                        dispatch_semaphore_signal(semaphore);
                    }];
                });
            }];
        });
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    });
}

- (void)showAlertWithTitle:(NSString *)title message:(NSString *)message cancelAction:(void(^__nullable)(void))cancelAction {
    dispatch_async(self.alertQueue, ^{
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (cancelAction) cancelAction();
                dispatch_semaphore_signal(semaphore);
            }]];
            [self.navigationController presentViewController:alertController animated:YES completion:nil];
        });
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    });
}

#pragma mark - Lazy Loading
- (UILabel *)localView {
    if (!_localView) {
        _localView = [[UILabel alloc] initWithFrame:CGRectZero];
        _localView.backgroundColor = [UIColor colorWithRed:240 / 255.0 green:240 / 255.0 blue:240 / 255.0 alpha:1.0];
        _localView.textColor = [UIColor grayColor];
        _localView.font = [UIFont systemFontOfSize:13];
        _localView.textAlignment = NSTextAlignmentCenter;
        [self.view addSubview:_localView];
    }
    return _localView;
}

- (UILabel *)remoteView {
    if (!_remoteView) {
        _remoteView = [[UILabel alloc] initWithFrame:CGRectZero];
        _remoteView.backgroundColor = [UIColor colorWithRed:240 / 255.0 green:240 / 255.0 blue:240 / 255.0 alpha:1.0];
        _remoteView.textColor = [UIColor grayColor];
        _remoteView.font = [UIFont systemFontOfSize:13];
        _remoteView.textAlignment = NSTextAlignmentCenter;
        [self.view addSubview:_remoteView];
    }
    return _remoteView;
}

- (UIScrollView *)controlScrollView {
    if (!_controlScrollView) {
        _controlScrollView = [[UIScrollView alloc] initWithFrame:CGRectZero];
        _controlScrollView.contentSize = CGSizeMake(SCREEN_WIDTH, 1);
        _controlScrollView.bounces = NO;
        _controlScrollView.showsVerticalScrollIndicator = YES;
        [_controlScrollView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(controlScrollViewDidTap)]];
        [self.view addSubview:_controlScrollView];
    }
    return _controlScrollView;
}

- (UILabel *)tipsView {
    if (!_tipsView) {
        _tipsView = [[UILabel alloc] initWithFrame:CGRectZero];
        _tipsView.textColor = [UIColor grayColor];
        _tipsView.font = [UIFont systemFontOfSize:12];
        _tipsView.numberOfLines = 0;
        [self.view addSubview:_tipsView];
    }
    return _tipsView;
}

@end