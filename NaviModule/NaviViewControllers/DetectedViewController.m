//
//  DetectedViewController.m
//  officialDemoNavi
//
//  Created by AutoNavi on 15/5/13.
//  Copyright (c) 2015年 AutoNavi. All rights reserved.
//

#import "DetectedViewController.h"

@interface DetectedViewController ()

@property (nonatomic, strong) MAPointAnnotation *carAnnotation;

@end

@implementation DetectedViewController

#pragma mark - Segmented Control Action

- (void)detectedModeAction:(UISegmentedControl *)sender
{
    NSString *selectedTitle = [sender titleForSegmentAtIndex:sender.selectedSegmentIndex];
    
    if ([selectedTitle isEqualToString:@"关闭"])
    {
        [self.naviManager setDetectedMode:AMapNaviDetectedModeNone];
    }
    else if ([selectedTitle isEqualToString:@"电子眼和特殊道路设施"])
    {
        [self.naviManager setDetectedMode:AMapNaviDetectedModeCameraAndSpecialRoad];
    }
    
    NSLog(@"DetectedMode:%ld", (long)self.naviManager.detectedMode);
}

#pragma mark - Utility

- (void)updateCarAnnotationCoordinate:(CLLocationCoordinate2D)coordinate
{
    [UIView animateWithDuration:0.2 animations:^{
        [self.carAnnotation setCoordinate:coordinate];
    }];
    
    [self.mapView setCenterCoordinate:coordinate animated:YES];
    [self.mapView setZoomLevel:17 animated:YES];
}

- (void)notifyNeedDriving
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"智能播报功能需要在驾车过程中体验~" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    
    [alert show];
}

#pragma mark - AMapNaviManager Delegate

- (void)naviManager:(AMapNaviManager *)naviManager didUpdateNaviLocation:(AMapNaviLocation *)naviLocation
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(naviLocation.coordinate.latitude, naviLocation.coordinate.longitude);
    
    [self updateCarAnnotationCoordinate:coordinate];
}

#pragma mark - MAMapView Delegate

- (MAAnnotationView *)mapView:(MAMapView *)mapView viewForAnnotation:(id<MAAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MAPointAnnotation class]])
    {
        static NSString *detectedReuseIndetifier = @"DetectedAnnotationIndetifier";
        MAAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:detectedReuseIndetifier];
        
        if (annotationView == nil)
        {
            annotationView = [[MAAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:detectedReuseIndetifier];
        }
        
        annotationView.canShowCallout   = NO;
        annotationView.draggable        = NO;
        annotationView.image            = [UIImage imageNamed:@"car"];
        
        return annotationView;
    }
    
    return nil;
}

#pragma mark - Handle Action

- (void)returnAction
{
    [self.naviManager setDetectedMode:AMapNaviDetectedModeNone];
    
    [super returnAction];
}

#pragma mark - Life Cycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self initToolBar];
    
    [self initIFlySpeech];
    
    [self configMapView];
    
    [self initCarAnnotation];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationController.toolbar.barStyle      = UIBarStyleBlack;
    self.navigationController.toolbar.translucent   = YES;
    [self.navigationController setToolbarHidden:NO animated:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self.naviManager setDetectedMode:AMapNaviDetectedModeCameraAndSpecialRoad];
    
    [self notifyNeedDriving];
}

#pragma mark - Initialization

- (void)initToolBar
{
    UIBarButtonItem *flexbleItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                 target:self
                                                                                 action:nil];
    
    UISegmentedControl *detectedModeSegmentedControl    = [[UISegmentedControl alloc] initWithItems:
                                                           [NSArray arrayWithObjects:
                                                            @"关闭",
                                                            @"电子眼和特殊道路设施",
                                                            nil]];
    detectedModeSegmentedControl.selectedSegmentIndex   = 1;
    detectedModeSegmentedControl.segmentedControlStyle  = UISegmentedControlStyleBar;
    [detectedModeSegmentedControl addTarget:self action:@selector(detectedModeAction:) forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem *detectedModeItem = [[UIBarButtonItem alloc] initWithCustomView:detectedModeSegmentedControl];
    
    self.toolbarItems = [NSArray arrayWithObjects:flexbleItem, detectedModeItem, flexbleItem, nil];
}

- (void)configMapView
{
    [self.mapView setFrame:self.view.bounds];
    
    [self.view insertSubview:self.mapView atIndex:0];
}

- (void)initCarAnnotation
{
    self.carAnnotation = [[MAPointAnnotation alloc] init];
    
    [self.mapView addAnnotation:self.carAnnotation];
}

@end
