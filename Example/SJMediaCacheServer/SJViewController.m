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
 
//#import <SJBaseVideoPlayer/SJIJKMediaPlaybackController.h>

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
    
//    NSURL *URL = [NSURL URLWithString:@"https://1892.cdn-vod.huaweicloud.com/asset/85a9db5846a39ff73b2cf7fc74aedc68/play_video/index.m3u8?auth_info=tFAn2OolEQPARAWVyO2bN7bij1jDEWKymxoYDrivzNHKy4%2Bb2GmfJAcrStTCBtGDjeVpmv8b6FF8RL1uBOOmGYtmVOeZYoEXipRXiYf7dKc%3D.51306f51734b69637757737632305533&vhost=1892.cdn-vod.huaweicloud.com"];
//    NSURL *URL = [NSURL URLWithString:@"http://hls.cntv.myalicdn.com/asp/hls/2000/0303000a/3/default/bca293257d954934afadfaa96d865172/2000.m3u8"];
    SJMediaCacheServer.shared.logOptions = MCSLogOptionSessionTask;
    
#pragma mark -
    
    NSString *url = nil;
    
    url = @"http://hls.cntv.myalicdn.com/asp/hls/450/0303000a/3/default/bca293257d954934afadfaa96d865172/450.m3u8";
//    url = @"http://video.youcheyihou.com/3240b282-6806-43c7-9c41-428d51a9fc1f.mp4";
    url = @"https://dh2.v.netease.com/2017/cg/fxtpty.mp4";
    
    NSURL *URL = [NSURL URLWithString:url];

    // playback URL
    NSURL *playbackURL = [SJMediaCacheServer.shared playbackURLWithURL:URL];

//    _player.playbackController = SJIJKMediaPlaybackController.new;
    
    // play
    _player.URLAsset = [SJVideoPlayerURLAsset.alloc initWithURL:playbackURL startPosition:0];
    
#pragma mark -
    
//    url = @"http://hls.cntv.myalicdn.com/asp/hls/450/0303000a/3/default/bca293257d954934afadfaa96d865172/450.m3u8";
////    url = @"https://dh2.v.netease.com/2017/cg/fxtpty.mp4";
//    URL = [NSURL URLWithString:url];
//
//    // 预加载
//    [SJMediaCacheServer.shared prefetchWithURL:URL preloadSize:20 * 1024 * 1024 progress:^(float progress) {
//
//        // progress ...
//
//    } completed:^(NSError * _Nullable error) {
//
//        // complete ...
//
//        if ( error != nil ) {
//            NSLog(@"error: %@", error);
//        }
//        else {
//            NSLog(@"done");
//        }
//    }];
//    for ( NSInteger i = 0 ; i < 10 ; ++ i ) {
//        // 预加载
//        [SJMediaCacheServer.shared prefetchWithURL:URL preloadSize:1 * 1024 * 1024 progress:^(float progress) {
//
//            // progress ...
//
//        } completed:^(NSError * _Nullable error) {
//
//            // complete ...
//
//            if ( error != nil ) {
//                NSLog(@"error: %@", error);
//            }
//            else {
//                NSLog(@"done");
//            }
//        }];
//
//    }
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
