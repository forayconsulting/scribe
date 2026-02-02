import SwiftUI

struct ProcessingView: View {
    let progress: Double
    let status: String

    var body: some View {
        VStack(spacing: 24) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            Text(status)
                .font(.headline)

            Text("\(Int(progress * 100))%")
                .font(.system(size: 36, weight: .light, design: .monospaced))
                .foregroundColor(.secondary)

            Text("Please wait while your recording is being transcribed...")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
