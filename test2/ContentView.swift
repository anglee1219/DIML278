//
//  ContentView.swift
//  test2
//
//  Created by Angela Lee on 5/26/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            
            // Add test button
            Button("Test Prompt System") {
                // Test the prompt loading and selection
                PromptManager.shared.testPromptSystem()
                
                // Test the scheduler
                PromptScheduler.shared.testScheduler()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
