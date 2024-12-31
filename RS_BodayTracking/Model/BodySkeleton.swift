//
//  BodySkeleton.swift
//  RS_BodayTracking
//
//  Created by esikmalazman on 21/11/2024.
//

import Foundation
import RealityKit
import ARKit

/// This class contain all the visualised entity
final class BodySkeleton: Entity {
  
  /// The property keep track joints  entity which later we can update their properties when updated ARBodyAnchor provided
  var joints: [String:Entity] = [:]
  /// The property keep track bones entity which later we can update their properties when updated BodyAnchor provided
  var bones: [String:Entity] = [:]
  
  required init(for bodyAnchor: ARBodyAnchor) {
    super.init()
    
    // Iterate all joint names define in AR skeleton
    for jointName in ARSkeletonDefinition.defaultBody3D.jointNames {
      var jointRadius: Float = 0.05
      var jointColor: UIColor = .green
      
      // Set color and size based on specific jointName
      // Green joints are actively tracked by ARKit
      // Yellow joints are not tracked and just follow the motion of the closest green parent
      
      switch jointName {
      case "neck_1_joint", "neck_2_joint", "neck_3_joint", "neck_4_joint", "head_joint", "left_shoulder_1_joint", "right_shoulder_1_joint":
        jointRadius *= 0.5
      case "jaw_joint", "chin_joint", "left_eye_joint", "left_eyeLowerLid_joint", "left_eyeUpperLid_joint", "left_eyeball_joint", "nose_joint", "right_eye_joint", "right_eyeLowerLid_joint", "right_eyeUpperLid_joint", "right_eyeball_joint":
        jointRadius *= 0.2
        jointColor = .yellow
      case _ where jointName.hasPrefix("spine_"):
        jointRadius *= 0.75
      case "left_hand_joint", "right_hand_joint":
        jointRadius *= 1
        jointColor = .green
      case _ where jointName.hasPrefix("left_hand") || jointName.hasPrefix("right_hand"):
        jointRadius *= 0.25
        jointColor = .yellow
      case _ where jointName.hasPrefix("left_toes") || jointName.hasPrefix("right_toes"):
        jointRadius *= 0.5
        jointColor = .yellow
      default:
        jointRadius = 0.05
        jointColor = .green
      }
      
      // Create Joint Entity, adds to joints directory, add to parent entity i.e. Skeleton Entity
      let jointEntity = createJoint(radius: jointRadius, color: jointColor)
      joints[jointName] = jointEntity
      self.addChild(jointEntity)
    }
    
    // Iterate all bones
    for bone in Bones.allCases {
      // Create a skeleton bone, if it empty we continue to next bone in our collection
      guard let skeletonBone = createSkeletonBone(
        bone: bone,
        bodyAnchor: bodyAnchor
      ) else {continue}
      
      // Create Bone Entity, adds to bones directory, add to parent entity i.e. Skeleton Entity
      let boneEntity = createBoneEntity(for: skeletonBone)
      bones[bone.name] = boneEntity
      self.addChild(boneEntity)
    }
    
    
    
  }
  
  @MainActor
  @preconcurrency required init() {
    fatalError("init() has not been implemented")
  }
  
  /// This method update the parameters of each Joint and Bone anytime ARKit update bodyAnchor
  func update(with bodyAnchor: ARBodyAnchor) {
    let rootPosition = simd_make_float3(bodyAnchor.transform.columns.3)
    
    // Iterate for each joint name and update its position and orientation
    for jointName in ARSkeletonDefinition.defaultBody3D.jointNames {
      // Obtain joint entity from our joints dictionary
      if let jointEntity = joints[jointName],
         let jointEntityTransform = bodyAnchor.skeleton.modelTransform(
          for: ARSkeleton.JointName(
            rawValue: jointName
          )
         ) {
        // Determine offset from the root and update joint position and orientation
        let jointEntityOffsetFromRoot = simd_make_float3(jointEntityTransform.columns.3) // relative to root
        jointEntity.position = jointEntityOffsetFromRoot + rootPosition // relative to world reference frame
        jointEntity.orientation = Transform(matrix: jointEntityTransform).rotation
      }
    }
    
    // Iterate for each bone and update its position and orientation
    for bone in Bones.allCases {
      let boneName = bone.name
      // Obtain bone entity and skeleton bone objects for each bone
      guard let entity = bones[boneName],
            let skeletonBone = createSkeletonBone(
              bone: bone,
              bodyAnchor: bodyAnchor
            ) else {
        continue
      }
      
      entity.position = skeletonBone.centerPosition
      // Automatically oritent cylinder to appropriate direction for bone
      entity.look(
        at: skeletonBone.fromJoint.position,
        from: skeletonBone.toJoint.position,
        relativeTo: nil
      )
    }
  }
  
  
  /// This method create a sphere entity for every joint in the skeleton
  private func createJoint(
    radius: Float,
    color: UIColor = .white
  ) -> Entity{
    let mesh = MeshResource.generateSphere(radius: radius)
    let material = SimpleMaterial(color: color, roughness: 0.8, isMetallic: false)
    let entity = ModelEntity(mesh: mesh, materials: [material])
    
    return entity
  }
  
  /// This method create skeleton bone from bone and BodyAnchor.
  /// Also, this not entity can be visualise but it an object contains parameters needed
  /// to visualise bone entity
  private func createSkeletonBone(
    bone: Bones,
    bodyAnchor : ARBodyAnchor
  ) -> SkeletonBone? {
    // Check every provided joint map to actual joint in skeleton
    guard
      let fromJointEntityTransform = bodyAnchor.skeleton.modelTransform(
        for: ARSkeleton.JointName(
          rawValue: bone.jointFromName
        )
      ), let toJoinEntityTransfrom = bodyAnchor.skeleton.modelTransform(
        for: ARSkeleton.JointName(
          rawValue: bone.jointToName
        )
      ) else {return nil}
    
    // All joints in body skeleton relative to hip join which also refer to root join
    // Determine root position in world coordinates
    let rootPosition = simd_make_float3(bodyAnchor.transform.columns.3)
    
    // Determine the offset from the root position and entity position in real world coordinate
    let jointFromEntityOffsetFromRoot = simd_make_float3(fromJointEntityTransform.columns.3) // relative to root (i.e hipjoint)
    let jointFromEntityPosition = jointFromEntityOffsetFromRoot + rootPosition // relative to world reference frame
    
    let jointToEntityOffsetFromRoot = simd_make_float3(toJoinEntityTransfrom.columns.3) // relative to root (i.e hipjoint)
    let jointToEntityPosition = jointToEntityOffsetFromRoot + rootPosition // relative to world reference frame
    
    // Create skeleton joint from each once we obtain the position
    let fromJoint = SkeletonJoint(name: bone.jointFromName, position: jointFromEntityPosition)
    let toJoint = SkeletonJoint(name: bone.jointToName, position: jointToEntityPosition)
    
    // Use 2 skeleton joints to create skeleton bone
    let skeletonBone = SkeletonBone(fromJoint: fromJoint, toJoint: toJoint)
    return skeletonBone
  }
  
  /// This method create a cyclinder entity for bone
  private func createBoneEntity(
    for skeletonBone: SkeletonBone,
    diameter: Float = 0.04,
    color: UIColor = .white
  ) -> Entity {
    let mesh = MeshResource.generateBox(size: [diameter, diameter, diameter], cornerRadius: diameter / 2)
    let material = SimpleMaterial(color: color, roughness: 0.5, isMetallic: true)
    let entity = ModelEntity(mesh: mesh, materials: [material])
    
    return entity
  }
}
