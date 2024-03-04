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
import CoreMotion
// Spatializes audio with the AirPods Pro
class AudioSpatializer {
    // The audio engine for PHASE
    let phaseEngine = PHASEEngine(updateMode: .automatic)
    // Reference frame (this is what you would use for calibration, but here we simply use the value measured at the start of motion or its identity)
    private var referenceFrame = matrix_identity_float4x4
    // The listener in the scene
    var listener: PHASEListener!
    // The sound source in the scene
    var source: PHASESource!
    var sources: [PHASESource] = []
    init() {
        // Create a Listener.
        listener = PHASEListener(engine: phaseEngine)
        // Set the Listener's transform to the origin with no rotation.
        listener.transform = referenceFrame
        // Attach the Listener to the Engine's Scene Graph via its Root Object.
        // This actives the Listener within the simulation.
        try! phaseEngine.rootObject.addChild(listener)
        // Create an Icosahedron Mesh.
        let mesh = MDLMesh.newIcosahedron(withRadius: 1.0, inwardNormals: false, allocator:nil)
        // Create a Shape from the Icosahedron Mesh.
        let shape = PHASEShape(engine: phaseEngine, mesh: mesh)
        // Create a Volumetric Source from the Shape.
        source = PHASESource(engine: phaseEngine, shapes: [shape])
        // Translate the source to the origin
        source.transform = referenceFrame;
        source.gain = 12.0
        // Attach the Source to the Engine's Scene Graph.
        // This actives the Listener within the simulation.
        try! phaseEngine.rootObject.addChild(source)
        let pipeline = PHASESpatialPipeline(flags: [.directPathTransmission, .lateReverb])!
        let mixer = PHASESpatialMixerDefinition(spatialPipeline: pipeline)
        pipeline.entries[PHASESpatialCategory.lateReverb]!.sendLevel = 0.1;
        phaseEngine.defaultReverbPreset = .mediumRoom
        // Create a node to play the sound
        try! phaseEngine.assetRegistry.registerSoundAsset(
               url: Bundle.main.url(forResource: "Forest_Amb", withExtension: "wav")!, identifier: "forest",
               assetType: .resident, channelLayout: nil,
               normalizationMode: .dynamic
        )
        try! phaseEngine.assetRegistry.registerSoundAsset(
               url: Bundle.main.url(forResource: "NHU05070109", withExtension: "wav")!, identifier: "pine",
               assetType: .resident, channelLayout: nil,
               normalizationMode: .dynamic
        )
        try! phaseEngine.assetRegistry.registerSoundAsset(
               url: Bundle.main.url(forResource: "Bird", withExtension: "wav")!, identifier: "bird",
               assetType: .resident, channelLayout: nil,
               normalizationMode: .dynamic
        )
        try! phaseEngine.assetRegistry.registerSoundAsset(
               url: Bundle.main.url(forResource: "Bird2", withExtension: "wav")!, identifier: "bird2",
               assetType: .resident, channelLayout: nil,
               normalizationMode: .dynamic
        )
        try! phaseEngine.assetRegistry.registerSoundAsset(
               url: Bundle.main.url(forResource: "Frog", withExtension: "wav")!, identifier: "frog",
               assetType: .resident, channelLayout: nil,
               normalizationMode: .dynamic
        )
        try! phaseEngine.assetRegistry.registerSoundAsset(
               url: Bundle.main.url(forResource: "Monkey", withExtension: "wav")!, identifier: "monkey",
               assetType: .resident, channelLayout: nil,
               normalizationMode: .dynamic
        )
        try! phaseEngine.assetRegistry.registerSoundAsset(
               url: Bundle.main.url(forResource: "Rain", withExtension: "wav")!, identifier: "rain",
               assetType: .resident, channelLayout: nil,
               normalizationMode: .dynamic
        )
        try! phaseEngine.assetRegistry.registerSoundAsset(
               url: Bundle.main.url(forResource: "Wind", withExtension: "wav")!, identifier: "wind",
               assetType: .resident, channelLayout: nil,
               normalizationMode: .dynamic
        )
        let samplerNodeDefinition = PHASESamplerNodeDefinition(
            soundAssetIdentifier: "forest",
            mixerDefinition: mixer // As yet undefined
        )
        // Set the Push Node's Calibration Mode to Relative SPL and Level to 0 dB.
        samplerNodeDefinition.playbackMode = .looping
        samplerNodeDefinition.setCalibrationMode(
            calibrationMode: .relativeSpl, level: 0.0
        )

        try! phaseEngine.assetRegistry.registerSoundEventAsset(
            rootNode:samplerNodeDefinition,
            identifier: "nature_event"
        )

        // Associate the Source and Listener with the Spatial Mixer in the Sound Event.
        let mixerParameters = PHASEMixerParameters()
        mixerParameters.addSpatialMixerParameters(identifier: mixer.identifier, source: source, listener: listener)

        let soundEvent = try! PHASESoundEvent(
            engine: phaseEngine,
            assetIdentifier: "nature_event",
            mixerParameters: mixerParameters // As yet undefined
        )

        // Start the engine and sound playback
        try! phaseEngine.start()
        soundEvent.prepare()
        soundEvent.start(completion: nil)
    }

    // Update the listener's position and orientation relative to each source
    // and attenuate gain using inverse square law
    func updateListenerTransform(updatedTransform: simd_float4x4) {
        listener.transform = updatedTransform
        for source in sources {
            let distance = sqrt(pow(source.transform.columns.3.x - updatedTransform.columns.3.x, 2) + pow(source.transform.columns.3.y - updatedTransform.columns.3.y, 2) + pow(source.transform.columns.3.z - updatedTransform.columns.3.z, 2))
            source.gain = Double(1 / pow(distance, 2))
        }
    }
    // Add a source to the audio scene with a specific transform
    func addSource(withTransform: simd_float4x4, identifier: String) {
        let mesh = MDLMesh.newIcosahedron(withRadius: 1.0, inwardNormals: false, allocator:nil)
        // Create a Shape from the Icosahedron Mesh.
        let shape = PHASEShape(engine: phaseEngine, mesh: mesh)
        // Create a Volumetric Source from the Shape.
        source = PHASESource(engine: phaseEngine, shapes: [shape])
        // Translate the source to the origin
        source.transform = withTransform;
        // Attach the Source to the Engine's Scene Graph.
        // This actives the Listener within the simulation.
        try! phaseEngine.rootObject.addChild(source)
        sources.append(source)
        let pipeline = PHASESpatialPipeline(flags: [.directPathTransmission, .lateReverb])!
        let mixer = PHASESpatialMixerDefinition(spatialPipeline: pipeline)
        pipeline.entries[PHASESpatialCategory.lateReverb]!.sendLevel = 0.1;
        phaseEngine.defaultReverbPreset = .mediumRoom
        // Associate the Source and Listener with the Spatial Mixer in the Sound Event.
        let mixerParameters = PHASEMixerParameters()
        mixerParameters.addSpatialMixerParameters(identifier: mixer.identifier, source: source, listener: listener)
        let samplerNodeDefinition = PHASESamplerNodeDefinition(
            soundAssetIdentifier: identifier,
            mixerDefinition: mixer // As yet undefined
        )
        // Set the Push Node's Calibration Mode to Relative SPL and Level to 0 dB.
        samplerNodeDefinition.playbackMode = .oneShot
        samplerNodeDefinition.setCalibrationMode(
            calibrationMode: .relativeSpl, level: 0.0
        )

        try! phaseEngine.assetRegistry.registerSoundEventAsset(
            rootNode:samplerNodeDefinition,
            identifier: "nature_event\(sources.count)"
        )
        let soundEvent = try! PHASESoundEvent(
            engine: phaseEngine,
            assetIdentifier: "nature_event\(sources.count)",
            mixerParameters: mixerParameters // As yet undefined
        )
        soundEvent.prepare()
        soundEvent.start()
    }
}
