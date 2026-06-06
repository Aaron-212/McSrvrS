import SwiftUI

struct ConnectionStatusLabel: View {
    let server: Server
    let fontSize: Font
    let fontWeight: Font.Weight
    
    var body: some View {
        Label(connectionStatusTitle, systemImage: "circle.fill")
            .font(fontSize)
            .fontWeight(fontWeight)
            .foregroundStyle(connectionStatusColor)
    }
    
    private var connectionStatusColor: Color {
        switch server.currentState {
        case .success:
            return .green
        case .error:
            return server.lastSeenDate == nil ? .red : .orange
        case .loading:
            return .accent
        }
    }
    
    private var connectionStatusTitle: LocalizedStringResource {
        switch server.currentState {
        case .success:
            return "Connected"
        case .error:
            return server.lastSeenDate == nil ? "Never Connected" : "Connection Lost"
        case .loading:
            return "Checking..."
        }
    }
} 
