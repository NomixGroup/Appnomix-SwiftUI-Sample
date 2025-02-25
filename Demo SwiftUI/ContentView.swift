//
//  ContentView.swift
//  Demo SwiftUI
//
//  Created by Narcis Badea on 06.05.2024.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, Appnomix Demo!")
                .foregroundColor(Color(UIColor.label))
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
