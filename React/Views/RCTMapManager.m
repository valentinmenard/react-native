/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "RCTMapManager.h"

#import "RCTBridge.h"
#import "RCTConvert+CoreLocation.h"
#import "RCTConvert+MapKit.h"
#import "RCTEventDispatcher.h"
#import "RCTMap.h"
#import "UIView+React.h"
#import "RCTPointAnnotation.h"

#import <MapKit/MapKit.h>

static NSString *const RCTMapViewKey = @"MapView";

@interface RCTMapManager() <MKMapViewDelegate>

@end

@implementation RCTMapManager

RCT_EXPORT_MODULE()

- (UIView *)view
{
  RCTMap *map = [[RCTMap alloc] init];
  map.delegate = self;
  return map;
}

RCT_EXPORT_VIEW_PROPERTY(showsUserLocation, BOOL)
RCT_EXPORT_VIEW_PROPERTY(zoomEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(rotateEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(pitchEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(scrollEnabled, BOOL)
RCT_EXPORT_VIEW_PROPERTY(maxDelta, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(minDelta, CGFloat)
RCT_EXPORT_VIEW_PROPERTY(legalLabelInsets, UIEdgeInsets)
RCT_EXPORT_VIEW_PROPERTY(mapType, MKMapType)
RCT_EXPORT_VIEW_PROPERTY(annotations, RCTPointAnnotationArray)
RCT_CUSTOM_VIEW_PROPERTY(region, MKCoordinateRegion, RCTMap)
{
  [view setRegion:json ? [RCTConvert MKCoordinateRegion:json] : defaultView.region animated:YES];
}

#pragma mark MKMapViewDelegate



- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
  if (![view.annotation isKindOfClass:[MKUserLocation class]]) {

    RCTPointAnnotation *annotation = (RCTPointAnnotation *)view.annotation;
    NSString *title = view.annotation.title ?: @"";
    NSString *subtitle = view.annotation.subtitle ?: @"";

    for (NSString *side in @[@"left", @"right"]) {
      NSString *accessoryViewSelector = [NSString stringWithFormat:@"%@CalloutAccessoryView", side];
      NSString *typeSelector = [NSString stringWithFormat:@"%@CalloutType", side];
      NSString *hasCheckSelector = [NSString stringWithFormat:@"has%@Callout", [side capitalizedString]];
      NSString *configSelector = [NSString stringWithFormat:@"%@CalloutConfig", side];

      [view setValue:nil forKey:accessoryViewSelector];
      if ([annotation valueForKey:hasCheckSelector]) {
        [view setValue:[UIButton buttonWithType:UIButtonTypeDetailDisclosure] forKey:accessoryViewSelector];

        if ([[annotation valueForKey:typeSelector] integerValue] == RCTPointAnnotationTypeImage) {
          [view setValue:[self generateCalloutImageAccessory:[annotation valueForKey:configSelector]] forKey:accessoryViewSelector];
        }
      }
    }

    NSDictionary *event = @{
                            @"target": mapView.reactTag,
                            @"action": @"annotation-click",
                            @"annotation": @{
                                @"id": annotation.identifier,
                                @"title": title,
                                @"subtitle": subtitle,
                                @"latitude": @(annotation.coordinate.latitude),
                                @"longitude": @(annotation.coordinate.longitude)
                                }
                            };

    [self.bridge.eventDispatcher sendInputEventWithName:@"topTap" body:event];
  }
}

- (bool)isLocalImage: (NSDictionary *)config
{
  if (config[@"image"] != nil) {
    if ([config[@"image"] isKindOfClass:[NSDictionary class]]) {
      if ([config[@"image"] objectForKey:@"__packager_asset"] != nil) {
        return true;
      }
    }
  }

  return false;
}

- (UIImageView *)generateCalloutImageAccessory:(NSDictionary *)config
{
  // Default width / height is 54
  int imageWidth = 54;
  int imageHeight = 54;

  if (config[@"imageSize"] != nil) {
    if ([config[@"imageSize"] objectForKey:@"height"] != nil) {
      imageHeight = [RCTConvert int:config[@"imageSize"][@"height"]];
    }

    if ([config[@"imageSize"] objectForKey:@"width"] != nil) {
      imageWidth = [RCTConvert int:config[@"imageSize"][@"width"]];
    }
  }

  UIGraphicsBeginImageContextWithOptions(CGSizeMake(imageWidth, imageHeight), NO, 0.0);
  UIImage *blank = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  UIImageView *calloutImageView = [[UIImageView alloc] initWithImage:blank];

  if ([self isLocalImage:config]) {
    // We have a local ressource, no web loading necessary
    NSString *ressourceName = [RCTConvert NSString:config[@"image"][@"uri"]];
    calloutImageView.image = [UIImage imageNamed:ressourceName];
  } else {
    NSString *uri = [RCTConvert NSString:config[@"image"]];

    if (config[@"defaultImage"] != nil) {
      NSString *defaultImagePath = [RCTConvert NSString:config[@"defaultImage"][@"uri"]];
      calloutImageView.image = [UIImage imageNamed:defaultImagePath];
    }

    // Load the real image async and replace the image with it
    [NSURLConnection sendAsynchronousRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:uri]] queue:[NSOperationQueue mainQueue] completionHandler:^(NSURLResponse *response, NSData *data, NSError *error) {
        if (!error) {
          if ([@[@200, @301, @302, @304] containsObject:@([(NSHTTPURLResponse *)response statusCode])]) {
            calloutImageView.image = [UIImage imageWithData:data];
          }
        }
    }];
  }

  return calloutImageView;
}

- (MKAnnotationView *)mapView:(__unused MKMapView *)mapView viewForAnnotation:(RCTPointAnnotation *)annotation
{
  if ([annotation isKindOfClass:[MKUserLocation class]]) {
    return nil;
  }

  MKPinAnnotationView *annotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"RCTAnnotation"];

  annotationView.canShowCallout = true;
  annotationView.animatesDrop = annotation.animateDrop;
  annotationView.pinColor = annotation.color;

  return annotationView;
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
  // Pass to js
  RCTPointAnnotation *annotation = (RCTPointAnnotation *)view.annotation;
  NSString *side = (control == view.leftCalloutAccessoryView) ? @"left" : @"right";

  NSDictionary *event = @{
      @"target": mapView.reactTag,
      @"side": side,
      @"action": @"callout-click",
      @"annotationId": annotation.identifier
    };

  [self.bridge.eventDispatcher sendInputEventWithName:@"topTap" body:event];
}


- (void)mapView:(RCTMap *)mapView didUpdateUserLocation:(MKUserLocation *)location
{
  if (mapView.followUserLocation) {
    MKCoordinateRegion region;
    region.span.latitudeDelta = RCTMapDefaultSpan;
    region.span.longitudeDelta = RCTMapDefaultSpan;
    region.center = location.coordinate;
    [mapView setRegion:region animated:YES];

    // Move to user location only for the first time it loads up.
    mapView.followUserLocation = NO;
  }
}

- (void)mapView:(RCTMap *)mapView regionWillChangeAnimated:(__unused BOOL)animated
{
  [self _regionChanged:mapView];

  mapView.regionChangeObserveTimer = [NSTimer timerWithTimeInterval:RCTMapRegionChangeObserveInterval
                                                             target:self
                                                           selector:@selector(_onTick:)
                                                           userInfo:@{ RCTMapViewKey: mapView }
                                                            repeats:YES];

  [[NSRunLoop mainRunLoop] addTimer:mapView.regionChangeObserveTimer forMode:NSRunLoopCommonModes];
}

- (void)mapView:(RCTMap *)mapView regionDidChangeAnimated:(__unused BOOL)animated
{
  [mapView.regionChangeObserveTimer invalidate];
  mapView.regionChangeObserveTimer = nil;

  [self _regionChanged:mapView];

  // Don't send region did change events until map has
  // started rendering, as these won't represent the final location
  if (mapView.hasStartedRendering) {
    [self _emitRegionChangeEvent:mapView continuous:NO];
  };
}

- (void)mapViewWillStartRenderingMap:(RCTMap *)mapView
{
  mapView.hasStartedRendering = YES;
  [self _emitRegionChangeEvent:mapView continuous:NO];
}


#pragma mark Private

- (void)_onTick:(NSTimer *)timer
{
  [self _regionChanged:timer.userInfo[RCTMapViewKey]];
}

- (void)_regionChanged:(RCTMap *)mapView
{
  BOOL needZoom = NO;
  CGFloat newLongitudeDelta = 0.0f;
  MKCoordinateRegion region = mapView.region;
  // On iOS 7, it's possible that we observe invalid locations during initialization of the map.
  // Filter those out.
  if (!CLLocationCoordinate2DIsValid(region.center)) {
    return;
  }
  // Calculation on float is not 100% accurate. If user zoom to max/min and then move, it's likely the map will auto zoom to max/min from time to time.
  // So let's try to make map zoom back to 99% max or 101% min so that there are some buffer that moving the map won't constantly hitting the max/min bound.
  if (mapView.maxDelta > FLT_EPSILON && region.span.longitudeDelta > mapView.maxDelta) {
    needZoom = YES;
    newLongitudeDelta = mapView.maxDelta * (1 - RCTMapZoomBoundBuffer);
  } else if (mapView.minDelta > FLT_EPSILON && region.span.longitudeDelta < mapView.minDelta) {
    needZoom = YES;
    newLongitudeDelta = mapView.minDelta * (1 + RCTMapZoomBoundBuffer);
  }
  if (needZoom) {
    region.span.latitudeDelta = region.span.latitudeDelta / region.span.longitudeDelta * newLongitudeDelta;
    region.span.longitudeDelta = newLongitudeDelta;
    mapView.region = region;
  }

  // Continously observe region changes
  [self _emitRegionChangeEvent:mapView continuous:YES];
}

- (void)_emitRegionChangeEvent:(RCTMap *)mapView continuous:(BOOL)continuous
{
  MKCoordinateRegion region = mapView.region;
  if (!CLLocationCoordinate2DIsValid(region.center)) {
    return;
  }

#define FLUSH_NAN(value) (isnan(value) ? 0 : value)

  NSDictionary *event = @{
    @"target": mapView.reactTag,
    @"continuous": @(continuous),
    @"region": @{
      @"latitude": @(FLUSH_NAN(region.center.latitude)),
      @"longitude": @(FLUSH_NAN(region.center.longitude)),
      @"latitudeDelta": @(FLUSH_NAN(region.span.latitudeDelta)),
      @"longitudeDelta": @(FLUSH_NAN(region.span.longitudeDelta)),
    }
  };
  [self.bridge.eventDispatcher sendInputEventWithName:@"topChange" body:event];
}

@end
