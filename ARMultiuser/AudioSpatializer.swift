/*

 AudioProvider.swift
 ARMultiuser

 Created by Evan Murray on 2/28/24.


Adapted from the Apple example code found here: https://developer.apple.com/documentation/arkit/arkit_in_ios/creating_a_multiuser_ar_experience
Tree model file credit: https://www.cgtrader.com/items/3713597/download-page
Sound file crecit: https://sound-effects.bbcrewind.co.uk/search?q=NHU05070109

The MIT License (MIT)

Copyright (c) 2024 Evan Murray

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

import PHASE
import SwiftUI
import PHASE
import CoreMotion
import AudioKit
import AudioKitEX
import SoundpipeAudioKit
// Tap class which schedules buffers to be played in PHASE
class PhaseTap: BaseTap {
    var pushNode: PHASEPushStreamNode?
    override func doHandleTapBlock(buffer: AVAudioPCMBuffer, at _: AVAudioTime) {
        if let pushNode = pushNode {
            pushNode.scheduleBuffer(buffer: buffer)
        }
    }
}
// Spatializes audio with the AirPods Pro
class AudioSpatializer: ObservableObject {
    // The audio engine for PHASE
    let phaseEngine = PHASEEngine(updateMode: .automatic)
    // The audio engine for AudioKit
    let akEngine = AudioEngine()
    // Audio Player from AudioKit wraps AVAudioPlayerNode
    let player = AudioPlayer(url: Bundle.main.url(forResource: "NHU05070109", withExtension: "wav")!)
    // Get motion from device motion sensor
    private let motionManager = CMMotionManager()
    // Reference frame (this is what you would use for calibration, but here we simply use the value measured at the start of motion or its identity)
    private var referenceFrame = matrix_identity_float4x4
    // Tap class to send audio to PHASE
    private let myTap: PhaseTap
    // The listener in the scene
    var listener: PHASEListener!
    init() {
        // Delay node from AudioKit for some cool effects
        let akNode = ZitaReverb(player!)
        // Silence the AudioKit Engine's output since we're using PHASE
        akEngine.output = Fader(akNode, gain: 0.0)
        // Create a Listener.
        listener = PHASEListener(engine: phaseEngine)
        // Set the Listener's transform to the origin with no rotation.
        listener.transform = referenceFrame
        // Attach the Listener to the Engine's Scene Graph via its Root Object.
        // This actives the Listener within the simulation.
        try! phaseEngine.rootObject.addChild(listener)
        // Create an Icosahedron Mesh.
        let mesh = MDLMesh.newIcosahedron(withRadius: 0.0142, inwardNormals: false, allocator:nil)
        // Create a Shape from the Icosahedron Mesh.
        let shape = PHASEShape(engine: phaseEngine, mesh: mesh)
        // Create a Volumetric Source from the Shape.
        let source = PHASESource(engine: phaseEngine, shapes: [shape])
        // Translate the Source 2 meters in front of the Listener and rotated back toward the Listener.
        var sourceTransform: simd_float4x4 = simd_float4x4()
        sourceTransform.columns.0 = simd_make_float4(-1.0, 0.0, 0.0, 0.0)
        sourceTransform.columns.1 = simd_make_float4(0.0, 1.0, 0.0, 0.0)
        sourceTransform.columns.2 = simd_make_float4(0.0, 0.0, -1.0, 0.0)
        sourceTransform.columns.3 = simd_make_float4(0.0, 0.0, 2.0, 1.0)
        source.transform = sourceTransform;
        // Attach the Source to the Engine's Scene Graph.
        // This actives the Listener within the simulation.
        try! phaseEngine.rootObject.addChild(source)
        let pipeline = PHASESpatialPipeline(flags: [.directPathTransmission, .lateReverb])!
        let mixer = PHASESpatialMixerDefinition(spatialPipeline: pipeline)
        pipeline.entries[PHASESpatialCategory.lateReverb]!.sendLevel = 0.5;
        phaseEngine.defaultReverbPreset = .largeRoom
        // Create a streaming node from AudioKit and hook it into the downstream Channel Mixer.
        let pushNodeDefinition = PHASEPushStreamNodeDefinition(mixerDefinition: mixer, format: AVAudioFormat(standardFormatWithSampleRate: 44100, channelLayout: AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!), identifier: "audioStream")
        // Set the Push Node's Calibration Mode to Relative SPL and Level to 0 dB.
        pushNodeDefinition.setCalibrationMode(calibrationMode: .relativeSpl, level: 0)
        // Register a Sound Event Asset with the Engine named "audioStreamEvent".
        try! phaseEngine.assetRegistry.registerSoundEventAsset(rootNode: pushNodeDefinition, identifier: "audioStreamEvent")
        // Settings for audio player
        player?.isLooping = true
        player?.isBuffered = true
        // Initialize tap with some settings
        myTap = PhaseTap(akNode, bufferSize: 2048, callbackQueue: .main)
        // Associate the Source and Listener with the Spatial Mixer in the Sound Event.
        let mixerParameters = PHASEMixerParameters()
        mixerParameters.addSpatialMixerParameters(identifier: mixer.identifier, source: source, listener: listener)
        // Create a Sound Event from the built Sound Event Asset "audioStreamEvent".
        let streamSoundEvent = try! PHASESoundEvent(engine: phaseEngine, assetIdentifier: "audioStreamEvent", mixerParameters: mixerParameters)
        // Start the engines and AudioKit's audio player.
        // This will internally start the Audio IO Thread.
        myTap.pushNode = streamSoundEvent.pushStreamNodes["audioStream"]
        try! akEngine.start()
        try! phaseEngine.start()
        player!.play()
        // Start the Sound Event and streaming.
        streamSoundEvent.start()
        myTap.start()
    }

    // Update the listener's position and orientation relative to ARKit
    func updateListenerTransform(updatedTransform: simd_float4x4) {
        listener.transform = updatedTransform
    }
}
