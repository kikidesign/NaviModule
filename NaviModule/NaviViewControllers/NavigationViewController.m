//
//  ZongheShowViewController.m
//  officialDemoNavi
//
//  Created by LiuX on 14-9-1.
//  Copyright (c) 2014年 AutoNavi. All rights reserved.
//

#import "NavigationViewController.h"
#import "NavPointAnnotation.h"
#import "MACombox.h"
#import "RouteShowViewController.h"
#import "MoreMenuView.h"
#import "APIKey.h"

#define kSetingViewHeight 215

typedef NS_ENUM(NSInteger, MapSelectPointState)
{
    MapSelectPointStateNone = 0,
    MapSelectPointStateStartPoint, // 当前操作为选择起始点
    MapSelectPointStateWayPoint,   // 当前操作为选择途径点
    MapSelectPointStateEndPoint,   // 当前操作为选择终止点
};


typedef NS_ENUM(NSInteger, NavigationTypes)
{
    NavigationTypeNone = 0,
    NavigationTypeGPS  = 1,    // 实时导航
};


typedef NS_ENUM(NSInteger, TravelTypes)
{
    TravelTypeCar = 0,    // 驾车方式
    TravelTypeWalk,       // 步行方式
};


@interface NavigationViewController () <AMapNaviViewControllerDelegate,
                                        MAComboxDelegate,
                                        UIGestureRecognizerDelegate,
                                        MoreMenuViewDelegate>
{
    UILabel *_strategyLabel;
    
    MACombox *_startPointCombox;
    MACombox *_endPointCombox;
    MACombox *_wayPointCombox;
    MACombox *_strategyCombox;
    
    MapSelectPointState _selectPointState;
    NavigationTypes     _naviType;
    TravelTypes         _travelType;
    
    BOOL _startCurrLoc;   // 起始点使用当前位置？
    BOOL _hasCurrLoc;
    
    UITapGestureRecognizer *_mapViewTapGesture;
    
    NSDictionary *_strategyMap;
    
    MoreMenuView *_moreMenuView;
}

@property (nonatomic, strong) AMapNaviViewController *naviViewController;

@property (nonatomic, strong) NavPointAnnotation *beginAnnotation;
@property (nonatomic, strong) NavPointAnnotation *wayAnnotation;
@property (nonatomic, strong) NavPointAnnotation *endAnnotation;

@property (nonatomic, weak) RouteShowViewController *routeShowVC;

@end

@implementation NavigationViewController


#pragma mark - Life Cycle

- (id)init
{
//    NSLog(@"init");
    self = [super init];
    if (self)
    {
        [self initCalRouteStrategyMap];
        [self initTravelType];
    }
    return self;
}


- (void)viewDidLoad
{
//    NSLog(@"viewDidLoad");
    if ([APIKey length] == 0)
    {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:@"apiKey为空，请检查key是否正确设置" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];
        
        [alert show];
    }
    
    [AMapNaviServices sharedServices].apiKey = (NSString *)APIKey;
    
    [MAMapServices sharedServices].apiKey = (NSString *)APIKey;
    
    [super viewDidLoad];
    
    [self initNaviViewController];
    
    [self configSettingViews];
    
    [self initGestureRecognizer];
}


- (void)viewWillAppear:(BOOL)animated
{
//        NSLog(@"viewWillAppear");
    [super viewWillAppear:animated];
    
    [self configMapView];
    
    [self initSettingState];
    
}


- (void)viewWillDisappear:(BOOL)animated
{
//     NSLog(@"viewWillDisappear");
    [super viewWillDisappear:animated];
    
    // 去掉手势
    [self.mapView removeGestureRecognizer:_mapViewTapGesture];
}



#pragma mark - Utils

- (void)initCalRouteStrategyMap
{
//    NSLog(@"initCalRouteStrategyMap");
    _strategyMap = @{@"速度优先"   : @0,
                     @"费用优先"   : @1,
                     @"距离优先"   : @2,
                     @"普通路优先"             : @3,
                     @"时间优先(躲避拥堵)"      : @4,
                     @"躲避拥堵且不走收费道路"   : @12};
}


- (void)initTravelType
{
//    NSLog(@"initTravelType");
    _travelType = TravelTypeCar;
}


- (void)configMapView
{
//    NSLog(@"configMapView");
    [self.mapView setDelegate:self];
    
    [self.mapView setFrame:CGRectMake(0, kSetingViewHeight,
                                      self.view.bounds.size.width,
                                      self.view.bounds.size.height - kSetingViewHeight)];
    
    [self.view insertSubview:self.mapView atIndex:0];
    
    [self.mapView addGestureRecognizer:_mapViewTapGesture];
    
    _hasCurrLoc = NO;
    
    self.mapView.showsUserLocation = YES;
}


- (void)initNaviViewController
{
//    NSLog(@"initNaviViewController");
    if (_naviViewController == nil)
    {
        _naviViewController = [[AMapNaviViewController alloc] initWithMapView:self.mapView delegate:self];
    }
}


- (void)configSettingViews
{
//    NSLog(@"configSettingViews");
    UILabel *startPointLabel = [self createTitleLabel:@"起   点"];
    startPointLabel.left     = 30;
    startPointLabel.top      = 50;
    [self.view addSubview:startPointLabel];
    
    _startPointCombox = [[MACombox alloc] initWithItems:@[@"", @"使用当前位置"]];
    _startPointCombox.delegate = self;
    _startPointCombox.left     = 90;
    _startPointCombox.top      = 50;
    [self.view insertSubview:_startPointCombox atIndex:0];
    
    
    UILabel *endPointLabel = [self createTitleLabel:@"终   点"];
    endPointLabel.left     = 30;
    endPointLabel.top      = 80;
    [self.view addSubview:endPointLabel];
    
    _endPointCombox = [[MACombox alloc] initWithItems:@[@"", @"地图选点"]];
    _endPointCombox.delegate = self;
    _endPointCombox.left     = 90;
    _endPointCombox.top      = 80;
    [self.view insertSubview:_endPointCombox atIndex:0];
    
    UIButton *routeBtn = [self createToolButton];
    [routeBtn setTitle:@"路径规划" forState:UIControlStateNormal];
    [routeBtn addTarget:self action:@selector(gpsNavi:) forControlEvents:UIControlEventTouchUpInside];
    routeBtn.left = 60;
    routeBtn.top  = 175;
    [self.view addSubview:routeBtn];

}


- (void)initGestureRecognizer
{
//    NSLog(@"initGestureRecognizer");
    _mapViewTapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                 action:@selector(handleSingleTap:)];
}


- (UILabel *)createTitleLabel:(NSString *)title
{
//    NSLog(@"createTitleLabel");
    UILabel *titleLabel = [[UILabel alloc] init];
    
    titleLabel.textAlignment = NSTextAlignmentLeft;
    titleLabel.font          = [UIFont systemFontOfSize:15];
    titleLabel.text          = title;
    [titleLabel sizeToFit];
    
    return titleLabel;
}


- (UIButton *)createToolButton
{
//    NSLog(@"createToolButton");
    UIButton *toolBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    
    toolBtn.layer.borderColor  = [UIColor lightGrayColor].CGColor;
    toolBtn.layer.borderWidth  = 0.5;
    toolBtn.layer.cornerRadius = 5;
    
    [toolBtn setBounds:CGRectMake(0, 0, 70, 30)];
    [toolBtn setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    toolBtn.titleLabel.font = [UIFont systemFontOfSize: 13.0];
    
    return toolBtn;
}


- (void)initSettingState
{
//    NSLog(@"initSettingState");
    _startPointCombox.inputTextField.text = @"";
    _wayPointCombox.inputTextField.text   = @"";
    _endPointCombox.inputTextField.text   = @"";
    
    _beginAnnotation = nil;
    _wayAnnotation   = nil;
    _endAnnotation   = nil;
    
    [self.mapView removeAnnotations:self.mapView.annotations];
    
    _selectPointState = MapSelectPointStateNone;
    _naviType = NavigationTypeNone;
}

- (void)initMoreMenuView
{
//    NSLog(@"initMoreMenuView");
    _moreMenuView = [[MoreMenuView alloc] initWithFrame:self.naviViewController.view.bounds];
    _moreMenuView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    _moreMenuView.delegate = self;
}

#pragma mark - Gesture Action

- (void)handleSingleTap:(UITapGestureRecognizer *)theSingleTap
{
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:[theSingleTap locationInView:self.mapView]
                                              toCoordinateFromView:self.mapView];
    
    if (_selectPointState == MapSelectPointStateStartPoint)
    {
        if (_beginAnnotation)
        {
            _beginAnnotation.coordinate = coordinate;
        }
        else
        {
            _beginAnnotation = [[NavPointAnnotation alloc] init];
            [_beginAnnotation setCoordinate:coordinate];
            _beginAnnotation.title        = @"起始点";
            _beginAnnotation.navPointType = NavPointAnnotationStart;
            [self.mapView addAnnotation:_beginAnnotation];
        }
    }else if (_selectPointState == MapSelectPointStateEndPoint)
    {
        if (_endAnnotation)
        {
            _endAnnotation.coordinate = coordinate;
        }
        else
        {
            _endAnnotation = [[NavPointAnnotation alloc] init];
            [_endAnnotation setCoordinate:coordinate];
            _endAnnotation.title        = @"终 点";
            _endAnnotation.navPointType = NavPointAnnotationEnd;
            [self.mapView addAnnotation:_endAnnotation];
        }
    }
}


#pragma mark - Button Actions

- (void)gpsNavi:(id)sender
{
    _naviType = NavigationTypeGPS;
    
    [self calRoute];
}


- (void)calRoute
{
    NSArray *startPoints;
    NSArray *wayPoints;
    NSArray *endPoints;
    
    if (_wayAnnotation)
    {
        wayPoints = @[[AMapNaviPoint locationWithLatitude:_wayAnnotation.coordinate.latitude
                                                longitude:_wayAnnotation.coordinate.longitude]];
    }
    
    if (_endAnnotation)
    {
        endPoints = @[[AMapNaviPoint locationWithLatitude:_endAnnotation.coordinate.latitude
                                                longitude:_endAnnotation.coordinate.longitude]];
    }
    
    if (_beginAnnotation)
    {
        startPoints = @[[AMapNaviPoint locationWithLatitude:_beginAnnotation.coordinate.latitude
                                                  longitude:_beginAnnotation.coordinate.longitude]];
    }
    
    if (_startCurrLoc)
    {
        if (endPoints.count > 0)
        {
            if (_travelType == TravelTypeCar)
            {
                [self.naviManager calculateDriveRouteWithEndPoints:endPoints
                                                         wayPoints:nil
                                                   drivingStrategy:[_strategyMap[@"速度优先"] integerValue]];
            }
            return;
        }
    }
    else
    {
        if (startPoints.count > 0 && endPoints.count > 0)
        {
            if (_travelType == TravelTypeCar)
            {
                [self.naviManager calculateDriveRouteWithStartPoints:startPoints
                                                           endPoints:endPoints
                                                           wayPoints:wayPoints
                                                     drivingStrategy:[_strategyMap[_strategyCombox.inputTextField.text] integerValue]];
            }
            else if (_travelType == TravelTypeWalk)
            {
                [self.naviManager calculateWalkRouteWithStartPoints:startPoints endPoints:endPoints];
            }
            
            return;
        }
    }
    [self.view makeToast:@"请先在地图上选点"
                duration:2.0
                position:[NSValue valueWithCGPoint:CGPointMake(160, 240)]];

}


#pragma mark - MAMapView Delegate

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[NavPointAnnotation class]])
    {
        static NSString *annotationIdentifier = @"annotationIdentifier";
        
        MAPinAnnotationView *pointAnnotationView = (MAPinAnnotationView*)[self.mapView dequeueReusableAnnotationViewWithIdentifier:annotationIdentifier];
        if (pointAnnotationView == nil)
        {
            pointAnnotationView = [[MAPinAnnotationView alloc] initWithAnnotation:annotation
                                                                  reuseIdentifier:annotationIdentifier];
        }
        
        pointAnnotationView.animatesDrop   = NO;
        pointAnnotationView.canShowCallout = NO;
        pointAnnotationView.draggable      = NO;
        
        NavPointAnnotation *navAnnotation = (NavPointAnnotation *)annotation;
        
        if (navAnnotation.navPointType == NavPointAnnotationStart)
        {
            [pointAnnotationView setPinColor:MAPinAnnotationColorGreen];
        }
        else if (navAnnotation.navPointType == NavPointAnnotationWay)
        {
            [pointAnnotationView setPinColor:MAPinAnnotationColorPurple];
        }
        else if (navAnnotation.navPointType == NavPointAnnotationEnd)
        {
            [pointAnnotationView setPinColor:MAPinAnnotationColorRed];
        }
        return pointAnnotationView;
    }
    
    return nil;
}


- (MAOverlayView *)mapView:(MAMapView *)mapView viewForOverlay:(id<MAOverlay>)overlay
{
    if ([overlay isKindOfClass:[MAPolyline class]])
    {
        MAPolylineView *polylineView = [[MAPolylineView alloc] initWithPolyline:overlay];
        polylineView.lineWidth = 5.0f;
        polylineView.strokeColor = [UIColor redColor];
        
        return polylineView;
    }
    return nil;
}

- (void)mapView:(MAMapView *)mapView didUpdateUserLocation:(MAUserLocation *)userLocation updatingLocation:(BOOL)updatingLocation
{
//    //取出当前位置的坐标
//    NSLog(@"latitude : %f,longitude: %f",userLocation.coordinate.latitude,userLocation.coordinate.longitude);
    
    // 第一次定位时才将定位点显示在地图中心
    if (!_hasCurrLoc)
    {
        _hasCurrLoc = YES;
        
        [self.mapView setCenterCoordinate:userLocation.coordinate];
        [self.mapView setZoomLevel:12 animated:NO];
    }
}

#pragma mark - AMapNaviManager Delegate

- (void)AMapNaviManager:(AMapNaviManager *)naviManager didPresentNaviViewController:(UIViewController *)naviViewController
{
    [super AMapNaviManager:naviManager didPresentNaviViewController:naviViewController];
    
    // 初始化语音引擎
    [self initIFlySpeech];
    
    if (_naviType == NavigationTypeGPS)
    {
        [self.naviManager startGPSNavi];
    }
}


- (void)AMapNaviManagerOnCalculateRouteSuccess:(AMapNaviManager *)naviManager
{
    
    [super AMapNaviManagerOnCalculateRouteSuccess:naviManager];
    
    if (_naviType == NavigationTypeGPS)
    {
        // 如果_routeShowVC不为nil，说明是偏航重算导致的算路，什么也不做
        if (!_routeShowVC)
        {
            RouteShowViewController *routeShowVC = [[RouteShowViewController alloc] initWithNavManager:naviManager
                                                                naviController:_naviViewController
                                                                       mapView:self.mapView];
            self.routeShowVC = routeShowVC;
            
            routeShowVC.title = @"线路展示";
            
            [self presentViewController:routeShowVC animated:YES completion:nil];

        }
    }

}


- (void)AMapNaviManager:(AMapNaviManager *)naviManager onCalculateRouteFailure:(NSError *)error
{
    [super AMapNaviManager:naviManager onCalculateRouteFailure:error];
}

#pragma mark - AManNaviViewController Delegate

- (void)AMapNaviViewControllerCloseButtonClicked:(AMapNaviViewController *)naviViewController
{
    [self.iFlySpeechSynthesizer stopSpeaking];
    
    self.iFlySpeechSynthesizer.delegate = nil;
    self.iFlySpeechSynthesizer          = nil;
    
    [self.naviManager stopNavi];
    [self.naviManager dismissNaviViewControllerAnimated:YES];
    
    if (_naviType == NavigationTypeGPS)
    {
        [self.mapView setDelegate:self];
        
        [_routeShowVC configMapView];
    }
    else
    {
        [self configMapView];
        
        [self initSettingState];
    }
}


- (void)AMapNaviViewControllerMoreButtonClicked:(AMapNaviViewController *)naviViewController
{
    if (_moreMenuView == nil)
    {
        [self initMoreMenuView];
    }
    
    [_moreMenuView setViewShowMode:naviViewController.viewShowMode];
    [_moreMenuView setShowNightType:naviViewController.showStandardNightType];
    
    [naviViewController.view addSubview:_moreMenuView];
}


- (void)AMapNaviViewControllerTrunIndicatorViewTapped:(AMapNaviViewController *)naviViewController
{
    [self.naviManager readNaviInfoManual];
}

#pragma mark - MoreMenuView Delegate

- (void)moreMenuViewFinishButtonClicked
{
    [_moreMenuView removeFromSuperview];
    
    _moreMenuView.delegate = nil;
    _moreMenuView = nil;
}

- (void)moreMenuViewViewModeChangeTo:(AMapNaviViewShowMode)viewShowMode
{
    if (self.naviViewController)
    {
        [self.naviViewController setViewShowMode:viewShowMode];
    }
}

- (void)moreMenuViewNightTypeChangeTo:(BOOL)isShowNightType
{
    if (self.naviViewController)
    {
        [self.naviViewController setShowStandardNightType:isShowNightType];
    }
}

#pragma mark - MACombox Delegate

- (void)dropMenuWillHide:(MACombox *)combox
{
    [self.view sendSubviewToBack:combox];
}


- (void)dropMenuWillShow:(MACombox *)combox
{
    [self.view bringSubviewToFront:combox];
    
    [_startPointCombox hideDropMenu];
    [_endPointCombox   hideDropMenu];
    [_wayPointCombox   hideDropMenu];
    [_strategyCombox   hideDropMenu];
}


- (void)maCombox:(MACombox *)macombox didSelectItem:(NSString *)item
{
    if (macombox == _startPointCombox)
    {
        if ([item isEqualToString:@"地图选点"])
        {
            _selectPointState = MapSelectPointStateStartPoint;
            
            _wayPointCombox.inputTextField.text = @"";
            _endPointCombox.inputTextField.text = @"";
            
            _startCurrLoc = NO;
        }
        else if ([item isEqualToString:@"使用当前位置"])
        {
            if (_beginAnnotation)
            {
                [self.mapView removeAnnotation:_beginAnnotation];
                _beginAnnotation = nil;
            }
            _startCurrLoc = YES;
            if (_selectPointState == MapSelectPointStateStartPoint)
            {
                _selectPointState = MapSelectPointStateNone;
            }
        }
        else
        {
            _startCurrLoc = NO;
            if (_selectPointState == MapSelectPointStateStartPoint)
            {
                _selectPointState = MapSelectPointStateNone;
            }
        }
    }
    else if (macombox == _wayPointCombox)
    {
        if ([item isEqualToString:@"地图选点"])
        {
            _selectPointState = MapSelectPointStateWayPoint;
            
            if (!_startCurrLoc) _startPointCombox.inputTextField.text = @"";
            _endPointCombox.inputTextField.text = @"";
        }
        else
        {
            if (_selectPointState == MapSelectPointStateWayPoint)
            {
                _selectPointState = MapSelectPointStateNone;
            }
        }
    }
    else if (macombox == _endPointCombox)
    {
        if ([item isEqualToString:@"地图选点"])
        {
            _selectPointState = MapSelectPointStateEndPoint;
            
            if (!_startCurrLoc) _startPointCombox.inputTextField.text = @"";
            _wayPointCombox.inputTextField.text = @"";
        }
        else
        {
            if (_selectPointState == MapSelectPointStateEndPoint)
            {
                _selectPointState = MapSelectPointStateNone;
            }
        }
    }
}


@end
