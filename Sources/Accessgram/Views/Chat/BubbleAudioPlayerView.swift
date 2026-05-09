import AVFoundation
import SwiftUI

@MainActor
struct BubbleAudioPlayerView: View {
    let file: TDFile?
    let duration: Int
    let viewModel: ChatViewModel

    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false
    @State private var audioProgress: Double = 0
    @State private var audioSpeed: Float = 1.0

    private let speedOptions: [Float] = [0.5, 1.0, 1.5, 2.0]

    private var speedLabel: String {
        switch audioSpeed {
        case 0.5: return "0.5×"
        case 1.5: return "1.5×"
        case 2.0: return "2×"
        default:  return "1×"
        }
    }

    var body: some View {
        let elapsed = Int(audioProgress * Double(max(duration, 1)))
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Button(action: { Task { await toggleAudio() } }, label: {
                    Image(systemName: isPlayingAudio ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.accentColor)
                })
                .buttonStyle(.plain)
                .accessibilityLabel(isPlayingAudio ? "Pause" : "Play")

                Slider(
                    value: Binding(
                        get: { audioProgress },
                        set: { v in
                            audioProgress = v
                            audioPlayer?.currentTime = v * (audioPlayer?.duration ?? 0)
                        }
                    ),
                    in: 0...1
                )
                .accessibilityLabel("Playback position")
                .accessibilityValue("\(formatSeconds(elapsed)) of \(formatSeconds(duration))")

                Button(action: { cycleSpeed() }, label: {
                    Text(speedLabel)
                        .font(.caption.bold().monospacedDigit())
                        .frame(minWidth: 30)
                })
                .buttonStyle(.plain)
                .accessibilityLabel("Playback speed \(speedLabel)")
                .accessibilityHint("Double-tap to change speed")
            }

            HStack {
                Text(formatSeconds(elapsed))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatSeconds(duration))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: 200)
        .task(id: isPlayingAudio) {
            guard isPlayingAudio else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(80))
                guard let player = audioPlayer else { break }
                if player.isPlaying {
                    audioProgress = player.duration > 0 ? player.currentTime / player.duration : 0
                } else {
                    isPlayingAudio = false
                    audioProgress = 0
                    break
                }
            }
        }
    }

    private func toggleAudio() async {
        if isPlayingAudio {
            audioPlayer?.stop()
            isPlayingAudio = false
            return
        }
        guard let file else { return }
        if let path = viewModel.localPath(for: file) {
            playAudio(at: path)
        } else {
            await viewModel.downloadFile(file)
            if let path = viewModel.localPath(for: file) {
                playAudio(at: path)
            }
        }
    }

    private func playAudio(at path: String) {
        let url = URL(fileURLWithPath: path)
        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.enableRate = true
        audioPlayer?.rate = audioSpeed
        if audioProgress > 0, let player = audioPlayer {
            player.currentTime = audioProgress * player.duration
        }
        audioPlayer?.play()
        isPlayingAudio = true
    }

    private func cycleSpeed() {
        let idx = speedOptions.firstIndex(of: audioSpeed) ?? 1
        audioSpeed = speedOptions[(idx + 1) % speedOptions.count]
        audioPlayer?.rate = audioSpeed
    }

    private func formatSeconds(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}
