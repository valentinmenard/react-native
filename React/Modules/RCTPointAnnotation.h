/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import <MapKit/MapKit.h>

typedef enum{
  RCTPointAnnotationTypeButton,
  RCTPointAnnotationTypeImage
} RCTPointAnnotationCalloutType;

@interface RCTPointAnnotation : MKPointAnnotation <MKAnnotation>

@property (nonatomic, copy) NSString *identifier;

@property (nonatomic, assign) MKPinAnnotationColor color;

@property (nonatomic, assign) BOOL hasLeftCallout;
@property (nonatomic, assign) BOOL hasRightCallout;

@property (nonatomic, assign) RCTPointAnnotationCalloutType leftCalloutType;
@property (nonatomic, assign) RCTPointAnnotationCalloutType rightCalloutType;

@property (nonatomic, copy) NSDictionary *rightCalloutConfig;
@property (nonatomic, copy) NSDictionary *leftCalloutConfig;

@property (nonatomic, assign) BOOL animateDrop;

@end
