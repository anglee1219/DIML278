import SwiftUI

struct GroupSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedFrequency = "Every 5 hours"
    @State private var isMuted = true
    let frequencies = ["Every 1 hour", "Every 3 hours", "Every 5 hours", "Every 8 hours"]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Text("Circle Settings")
                    .font(.custom("Markazi Text", size: 24))
                    .bold()

                Spacer()

                Button("Done") {
                    dismiss()
                }
            }
            .padding(.horizontal)

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Prompt Frequency:")
                    .font(.custom("Markazi Text", size: 18))

                Menu {
                    ForEach(frequencies, id: \.self) { freq in
                        Button(freq) {
                            selectedFrequency = freq
                        }
                    }
                } label: {
                    Text(selectedFrequency)
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color(red: 1, green: 0.95, blue: 0.85))
                        .cornerRadius(10)
                }

                Text("Mute Notifications")
                    .font(.custom("Markazi Text", size: 18))
                    .padding(.top, 16)

                Menu {
                    Button("Muted") { isMuted = true }
                    Button("Unmuted") { isMuted = false }
                } label: {
                    Text(isMuted ? "Muted" : "Unmuted")
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(Color(red: 1, green: 0.95, blue: 0.85))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)

            Divider()

            // Invite Section
            Text("Invite More Friends")
                .font(.custom("Markazi Text", size: 20))
                .bold()
                .padding(.horizontal)

            TextField("Search Friends...", text: .constant(""))
                .padding(10)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)

            ScrollView {
                LazyVGrid(columns: Array(repeating: .init(.flexible()), count: 2), spacing: 20) {
                    ForEach(["Steph Mulkens", "Nick Lowe", "Nicole Reinhardt", "Tanya Benson"], id: \.self) { name in
                        VStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(Image(systemName: "plus").foregroundColor(.black))

                            Text(name)
                                .font(.custom("Markazi Text", size: 16))
                        }
                    }
                }
                .padding()
            }

            Spacer()
        }
        .padding(.top, 20)
        .background(Color(red: 1, green: 0.988, blue: 0.929))
    }
}

#Preview {
    GroupSettingsView()
}
//
//  GroupSettingsView.swift
//  test2
//
//  Created by Angela Lee on 5/31/25.
//

