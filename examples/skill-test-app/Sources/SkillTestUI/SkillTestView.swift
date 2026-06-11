import SwiftUI

public struct SkillTestView: View {
    @State private var tapCount = 0
    @State private var note = ""

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Skill Test App")
                    .font(.title.bold())
                    .accessibilityIdentifier("title")

                Text("Taps: \(tapCount)")
                    .font(.title2)
                    .accessibilityIdentifier("tap-count")

                Button("Tap Me") {
                    tapCount += 1
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("tap-button")

                TextField("Type here", text: $note)
                    .textFieldStyle(.roundedBorder)
                    .padding(.horizontal)
                    .accessibilityIdentifier("note-field")

                Text(note.isEmpty ? "Waiting for input..." : "You typed: \(note)")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("note-preview")
            }
            .padding()
            .navigationTitle("Simulator Browser Test")
        }
    }
}

#Preview("Default") {
    SkillTestView()
}
