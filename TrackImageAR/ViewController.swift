//
//  ViewController.swift
//  TrackImageAR
//
//  Created by Andre Frank on 17.09.23.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {

    //MARK: - Outlets
    @IBOutlet var sceneView: ARSCNView!
    
    //MARK: - Propeties
    ///The video player
    private lazy var avPlayer:AVPlayer? = {
        // Show video
        guard let videoURL = Bundle.main.url(forResource: "video", withExtension: "mp4")
        else { return nil }
        
        let player = AVPlayer(url: videoURL)
        
        return player
    }()
    
    private var particles:SCNParticleSystem {
       SCNParticleSystem(named: "particle.scnp", inDirectory:"art.scnassets")!
    }
    
    ///Track manual start/pause player
    private var isVideoPaused:Bool = false
    private var isVideoReversed:Bool =  true
    
    ///Combines current tracking state of ARImages with manual start/pause video
    /// which lets the video to pause when tracking is off and play video when regain tracking of the ARImage
    private var isPlaying:Bool = false {
        didSet {
            //Do this on main thread, although not sure if necessary
            DispatchQueue.main.async { [self] in
                self.isPlaying ? avPlayer?.play() : avPlayer?.pause()
                if self.isVideoReversed && self.isPlaying {
                    
                    if let node = getNodeWithName("container"){
                        self.isVideoReversed = false
                        installParticles(node)
                    }
                }
            }
        }
    }
    
//MARK: - Viewcontroller Lifecycle management methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene(named: "art.scnassets/namecard.scn")!
        
        if let avPlayer {
            configureVideoDidFinishNotification(avPlayer)
        }

        // Set the scene to the view
        
        sceneView.scene = scene
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        setupARImageTracking("AR Resources")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    private func configureVideoDidFinishNotification(_ player:AVPlayer) -> Void {
        NotificationCenter.default.addObserver(self, selector: #selector(didFinishPlaying(_ :)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object:player.currentItem)
    }
    
    private func setupARImageTracking(_ groupName:String){
        // Create a session configuration
        let configuration = ARImageTrackingConfiguration()
        
        
        guard let arImages = ARReferenceImage.referenceImages(inGroupNamed:groupName, bundle: nil) else {
            fatalError("Couldn' find AR images in Main Bundle")
        }
        
        configuration.trackingImages = arImages

        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    
    //MARK: - Class Deinitialization

    deinit {
        //Remove AVPlayer notfication
        NotificationCenter.default.removeObserver(self)
    }
}


//MARK: - ARSCNView Session and Renderer Delegate methods
extension ViewController {
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor =  anchor as? ARImageAnchor else { return }
        
        //Switch between play or pause mode for video according to the
        //current tracking state or user
        self.isPlaying = imageAnchor.isTracked && !isVideoPaused
        
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        //Check Image Anchor found
        guard anchor is  ARImageAnchor  else { return }
        
        //Find container node from scene (which is hidden by default after loading)
        guard let container = getNodeWithName("container") else { return }
        
        //Remove container from scene
        container.removeFromParentNode()
        
        //Add container with subnodes to image anchor node
        node.addChildNode(container)
        
        //Show it
        DispatchQueue.main.async {
            
            container.isHidden = false
            node.isHidden = false
        }
        
        //Check AVPlayer instance and create video node
        guard let avPlayer else { return }
        let videoNode = SKVideoNode(avPlayer: avPlayer)
        //Give it a name for reference later on due touch event
        videoNode.name = "videoPlayer"
        
        //Create new scene with specific size
        let videoScene = SKScene(size: CGSize(width: 720, height: 1280))
        
        //Center video node in video plane in center
        videoNode.position = CGPointMake(videoScene.size.width/2, videoScene.size.height/2)
        
        //Make video same size as video plane
        videoNode.size = videoScene.size
        
        //Upside down video to restore correct orientation
        videoNode.yScale = -1
        
        
        //Add video node to the new scene
        videoScene.addChild(videoNode)
        
        //Get the video container where the video scene will attach to
        guard let videoContainer =  node.childNode(withName: "plane", recursively: true) else { return }
        //Attach new video scene as content
        videoContainer.geometry?.firstMaterial?.diffuse.contents = videoScene
        
        //Start to play video with normal speed
        self.isPlaying = true
        
        
        //Particle
        //installParticles(container)
            
    }
    
    private func getNodeWithName(_ name:String) -> SCNNode? {
        return sceneView.scene.rootNode.childNode(withName: name, recursively:true)
    }
    
    private func installParticles(_ container:SCNNode){
        if let particleNode = container.childNode(withName: "particles", recursively: false){
            particleNode.removeFromParentNode()
        }
        
        let particleNode = SCNNode()
        
        particleNode.name = "particles"
        
        particleNode.addParticleSystem(particles)
        container.addChildNode(particleNode)
    }
    
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user
        
    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay
        
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required
        
    }
}


//MARK: - Touch event methods
extension ViewController {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        //1.Get location of touch
        guard let location = touches.first?.location(in: self.sceneView) else { return }
        
        //2. Evaluate node hits
        let hitResults = sceneView.hitTest(location)
        
        //3. Contents of video scene touched
        if let scene = hitResults.first?.node.geometry?.firstMaterial?.diffuse.contents as? SKScene, let _ = scene.childNode(withName: "videoPlayer") as? SKVideoNode {
            //Toggle play/pause of video
            isVideoPaused.toggle()
        }
        
    }
}


//MARK: - AVPlayer Notification
extension ViewController {
    
    @objc func didFinishPlaying(_ notification:NSNotification){
        if let player = notification.object as? AVPlayerItem {
            
            //Rewind to start
            self.isVideoPaused = true
            
            player.seek(to: CMTime.zero,completionHandler:{ success in
                if success {
                    self.isVideoReversed = true
                }
            })
        }
        
    }
}
