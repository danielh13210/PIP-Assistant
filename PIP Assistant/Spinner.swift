//
//  Spinner.swift
//  PIP Assistant
//
//  Created by Tinkertanker on 24/1/26.
//

import SwiftUI

struct Spinner: View {
    var body: some View {
        ProgressView() // default spinner
            .progressViewStyle(CircularProgressViewStyle()) .scaleEffect(2) // make it bigger
    }
}

#Preview {
    Spinner()
}
