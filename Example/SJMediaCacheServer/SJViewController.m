//
//  SJViewController.m
//  SJMediaCacheServer
//
//  Created by changsanjiang@gmail.com on 05/30/2020.
//  Copyright (c) 2020 changsanjiang@gmail.com. All rights reserved.
//

#import "SJViewController.h"
#import <SJVideoPlayer/SJVideoPlayer.h>
#import <Masonry/Masonry.h>

#import "SJMediaCacheServer.h"
#import "MCSLogger.h"

@interface SJViewController ()
@property (nonatomic, strong, nullable) SJVideoPlayer *player;
@end

@implementation SJViewController

- (BOOL)shouldAutorotate {
    return NO;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self _setupViews];
    
    SJMediaCacheServer.shared.enabledConsoleLog = YES;
    
    NSURL *URL = [NSURL URLWithString:@"https://1892.cdn-vod.huaweicloud.com/asset/85a9db5846a39ff73b2cf7fc74aedc68/play_video/index.m3u8?auth_info=tFAn2OolEQPARAWVyO2bN7bij1jDEWKymxoYDrivzNHKy4%2Bb2GmfJAcrStTCBtGDjeVpmv8b6FF8RL1uBOOmGYtmVOeZYoEXipRXiYf7dKc%3D.51306f51734b69637757737632305533&vhost=1892.cdn-vod.huaweicloud.com"];
//    NSURL *URL = [NSURL URLWithString:@"http://hls.cntv.myalicdn.com/asp/hls/2000/0303000a/3/default/bca293257d954934afadfaa96d865172/2000.m3u8"];
    
    // playback URL
    NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLWithURL:URL];
    
    // play
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];
}

- (void)_setupViews {
    _player = SJVideoPlayer.player;
    _player.pauseWhenAppDidEnterBackground = NO;
    [self.view addSubview:_player.view];
    [_player.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.right.offset(0);
        make.centerY.offset(0);
        make.height.offset(210);
    }];
}
@end
