import SwiftUI
import AVFoundation
import MediaPlayer

struct SpatialAudioDebugView: View {
    @State private var distance: Float = 0.0  // Represents lateral position for panning
    @State private var isPlaying: Bool = false
    @State private var audioFile: AVAudioFile?  // Changed to @State

    private let audioEngine = AVAudioEngine()
    private let audioPlayer = AVAudioPlayerNode()
    private let audioEnvironmentNode = AVAudioEnvironmentNode()
    
    private let maxDistance: Float = 10.0
    @State private var audioBuffer: AVAudioPCMBuffer?

    var body: some View {
        VStack(spacing: 20) {
            Text("Spatial Audio Debug")
                .font(.largeTitle)
                .padding()
            
            // Slider to move sound source laterally
            VStack(alignment: .leading) {
                Text("Lateral Position: \(String(format: "%.2f", distance)) meters")
                    .font(.headline)
                Slider(value: Binding(
                    get: { distance },
                    set: { newValue in
                        distance = newValue
                        updateAudioPosition()
                    }
                ), in: -maxDistance...maxDistance)
            }
            .padding()
            
            // Control Buttons
            HStack(spacing: 20) {
                Button(action: {
                    if isPlaying {
                        stopAudio()
                    } else {
                        startAudio()
                    }
                    isPlaying.toggle()
                }) {
                    Text(isPlaying ? "Stop Audio" : "Play Audio")
                        .fontWeight(.bold)
                        .padding()
                        .background(isPlaying ? Color.red : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .onAppear(perform: setupAudio)
        .padding()
    }
    
    func setupAudio() {
        // Configure audio session for playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback)
            try audioSession.setMode(.default)
            try audioSession.setActive(true)
        } catch {
            print("Audio Session error: \(error)")
        }
        
        // Load audio file
        guard let url = Bundle.main.url(forResource: "ping", withExtension: "mp3") else {
            print("Audio file not found.")
            return
        }
        
        do {
            audioFile = try AVAudioFile(forReading: url)
        } catch {
            print("Error loading audio file: \(error)")
            return
        }
        
        // Prepare audio buffer for looping
        if let file = audioFile {
            let processingFormat = file.processingFormat
            let frameCount = UInt32(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: processingFormat, frameCapacity: frameCount) else {
                print("Unable to create PCM buffer.")
                return
            }
            do {
                try file.read(into: buffer)
                audioBuffer = buffer
            } catch {
                print("Error reading audio file into buffer: \(error)")
            }
        }
        
        // Attach nodes
        audioEngine.attach(audioPlayer)
        audioEngine.attach(audioEnvironmentNode)
        
        // Set rendering algorithm and source mode
        audioEnvironmentNode.renderingAlgorithm = .equalPowerPanning
        audioPlayer.sourceMode = .spatializeIfMono
        
        // Connect nodes: Player -> Environment -> Main Mixer
        if let file = audioFile {
            audioEngine.connect(audioPlayer, to: audioEnvironmentNode, format: file.processingFormat)
        }
        audioEngine.connect(audioEnvironmentNode, to: audioEngine.mainMixerNode, format: nil)
        
        // Set environment parameters for distance attenuation
        audioEnvironmentNode.distanceAttenuationParameters.distanceAttenuationModel = .exponential
        audioEnvironmentNode.distanceAttenuationParameters.referenceDistance = 1.0
        audioEnvironmentNode.distanceAttenuationParameters.maximumDistance = maxDistance
        audioEnvironmentNode.distanceAttenuationParameters.rolloffFactor = 1.0
        
        // Schedule looping playback using buffer before starting the engine
        if let buffer = audioBuffer {
            audioPlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
        } catch {
            print("Audio engine failed to start: \(error)")
        }
        
        // Initialize audio position after engine has started
        updateAudioPosition()
    }
    
    private func startAudio() {
        if !audioPlayer.isPlaying {
            audioPlayer.play()
            updateNowPlayingInfo()  // Update Now Playing info when audio starts
        }
    }
    
    private func stopAudio() {
        audioPlayer.stop()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil  // Clear Now Playing info
    }
    
    private func updateAudioPosition() {
        // Set listener at origin with default orientation
        audioEnvironmentNode.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)
        audioEnvironmentNode.listenerAngularOrientation = AVAudio3DAngularOrientation(yaw: 0, pitch: 0, roll: 0)
        
        // Update source position along the x-axis for lateral (panning) effect
        if let spatialMixer = audioPlayer as? AVAudio3DMixing {
            spatialMixer.position = AVAudio3DPoint(x: distance, y: 0, z: 0)
        }
        
        print("Listener Position: \(audioEnvironmentNode.listenerPosition)")
        if let spatialMixer = audioPlayer as? AVAudio3DMixing {
            print("Source Position: \(spatialMixer.position)")
        }
    }
    
    private func updateNowPlayingInfo() {
        // Update metadata to display in Control Center
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Ping Sound",
            MPMediaItemPropertyArtist: "SpatialAudioDebug",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
    }
}
