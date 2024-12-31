//
//  SkeletonBone.swift
//  RS_BodayTracking
//
//  Created by esikmalazman on 21/11/2024.
//

import Foundation
import RealityKit

/// Connect 2 joints in Skeleton
struct SkeletonBone {
  var fromJoint : SkeletonJoint
  var toJoint : SkeletonJoint
  
  /// This property calculate the midpoint/center position between 2 joints
  var centerPosition : SIMD3<Float> {
    [
      (fromJoint.position.x + toJoint.position.x)/2,
      (fromJoint.position.y + toJoint.position.y)/2,
      (fromJoint.position.z + toJoint.position.z)/2
    ]
  }
  
  /// This property calculate the straight line distance between 2 joints
  var length : Float {
    simd_distance(fromJoint.position, toJoint.position)
  }
  
}
