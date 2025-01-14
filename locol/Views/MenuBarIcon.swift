import SwiftUI

struct MenuBarIcon: View {
    var body: some View {
        Image("opentelemetry-icon-black")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 18, height: 18)
    }
}

#Preview {
    MenuBarIcon()
} 