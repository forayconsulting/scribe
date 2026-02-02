import SwiftUI

struct RecordButton: View {
    let isRecording: Bool
    let action: () -> Void

    @State private var isPulsing = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(isRecording ? Color.red.opacity(0.2) : Color.red.opacity(0.1))
                    .frame(width: 100, height: 100)
                    .scaleEffect(isPulsing ? 1.1 : 1.0)

                Circle()
                    .fill(isRecording ? Color.red : Color.red.opacity(0.8))
                    .frame(width: 70, height: 70)

                if isRecording {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white)
                        .frame(width: 24, height: 24)
                } else {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 30, height: 30)
                }
            }
        }
        .buttonStyle(.plain)
        .onChange(of: isRecording) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            } else {
                withAnimation(.default) {
                    isPulsing = false
                }
            }
        }
    }
}
