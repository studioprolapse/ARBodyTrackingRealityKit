//
//  ARContainerView.swift
//  RS_BodayTracking
//
//  Created by esikmalazman on 21/11/2024.
//

import SwiftUI
import RealityKit
import ARKit

private var bodySkeleton: BodySkeleton?
private let bodySkeletonAnchor:AnchorEntity = AnchorEntity()

struct ARContainerView: UIViewRepresentable {
  typealias UIViewType = ARView
  
  func makeUIView(context: Context) -> ARView {
    let arView = ARView(
      frame: .zero,
      cameraMode: .ar,
      automaticallyConfigureSession: true
    )
    arView.setupForBodyTracking()
    arView.scene.addAnchor(bodySkeletonAnchor)
    return arView
  }
  
  func updateUIView(_ uiView: ARView, context: Context) {}
}

extension ARView: ARSessionDelegate {
  func setupForBodyTracking() {
    let configuration = ARBodyTrackingConfiguration()
    self.session.run(configuration)
    
    self.session.delegate = self
  }
  
  public func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    // Obtain bodyAnchor from our scene
    for anchor in anchors {
      
      guard let bodyAnchor = anchor as? ARBodyAnchor else {
        print("Not a bodyAnchor")
        return
      }
    
      if let bodySkeleton = bodySkeleton {
        // Check if BodySkeleton exist, we update all joints and bones position and orientation
        bodySkeleton.update(with: bodyAnchor)
      } else {
        // if BodySkeleton not yet exist which mean a body detected for first time.
        // Create bodySkeleton entity and add to bodySkeletonAnchor
        bodySkeleton = BodySkeleton(for: bodyAnchor)
        bodySkeletonAnchor.addChild(bodySkeleton!)
      }
      
    }
  }
}
