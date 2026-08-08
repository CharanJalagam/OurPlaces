
import SwiftUI

struct TimelineView: View {
    
    @StateObject private var viewModel = TimelineViewModel()
    @State private var selectedPlaceForDetails: TimelineViewModel.VisitWithPlace?
    var body: some View {
        NavigationStack{
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                content
            }
            .task {
                await viewModel.fetchTimeline()
            }
            .refreshable {
                await viewModel.fetchTimeline()
            }
        }
        .toolbarVisibility(.hidden, for: .navigationBar)
    }
    
    @ViewBuilder
    private var content: some View {
        
        VStack{
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Places")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(.accent)
                    
                    Text("Your journey through time")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(.accent)
                }
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top)
            
            if viewModel.isLoading {
                SkeletonTimelineView()
            }
            else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
                Spacer()
            }
            else if viewModel.groupedVisits.isEmpty {
                Text("No memories yet")
                    .foregroundColor(.gray)
                    .padding()
                Spacer()
            }
            else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 28) {
                        
                        ForEach(viewModel.groupedVisits, id: \.date) { group in
                            
                            Text(group.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.title2)
                                .foregroundColor(.gray)
                                .padding(.horizontal)
                            
                            ForEach(group.visits) { visit in
                                TimelineCardView(visit: visit)
                                    .onTapGesture {
                                        navigateToInternal(visit)
                                    }
                            }
                        }
                    }
                    .padding(.vertical)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                            .font(.system(size: 28))
                            .foregroundStyle(.gray.opacity(0.7))
                        
                        Text("End of places")
                            .font(.subheadline)
                            .foregroundStyle(.gray.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationDestination(item: $selectedPlaceForDetails) { visit in
            MemoriesInternalVIew(visit: visit)
        }
    }
    private func navigateToInternal(_ visit: TimelineViewModel.VisitWithPlace) {
        
        selectedPlaceForDetails = visit
    }
}

struct TimelineCardView: View {
    
    let visit: TimelineViewModel.VisitWithPlace
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            
            // Timeline Line
            VStack {
                ZStack{
                    Circle()
                        .fill(.accent)
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: pinIcon(category: visit.place.category))
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .semibold))
                }
                
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 2)
            }
            
            // Card
            VStack(alignment: .leading, spacing: 12) {
                
                HStack {
                    Text(visit.place.name)
                        .font(.headline)
                    
                    Spacer()
                    
                    Text(timeString(from: visit.visitDate))
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                Text(visit.place.category)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Text(visit.place.description ?? "")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if !visit.photos.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(visit.photos.prefix(4)) { photo in
                                CachedAsyncImage(url: URL(string: photo.image_url)) { phase in
                                    switch phase {
                                    case .empty:
                                        Color.gray.opacity(0.3)
                                        
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                        
                                    case .failure:
                                        Color.gray.opacity(0.3)
                                    }
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(radius: 3)
        }
        .padding(.horizontal)
    }
    
    private func timeString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
    
    func pinIcon(category: String) -> String{
            switch category.lowercased() {
            case "food":
                return "fork.knife"
            case "cafe" :
                return "cup.and.saucer.fill"
            case "historic":
                return "building.columns.fill"
            case "nature":
                return "leaf.fill"
            case "shopping":
                return "bag.fill"
            case "religious":
                return "sparkles"
            case "entertainment":
                return "theatermasks.fill"
            default:
                return "mappin.fill"
            }
    }
}
struct SkeletonTimelineView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(0..<4) { _ in
                    SkeletonCard()
                }
            }
            .padding()
        }
    }
}
struct SkeletonCard: View {
    @State private var animating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            RoundedRectangle(cornerRadius: 8)
                .frame(height: 20)
            
            RoundedRectangle(cornerRadius: 8)
                .frame(height: 14)
            
            HStack {
                RoundedRectangle(cornerRadius: 12)
                    .frame(width: 80, height: 80)
                
                RoundedRectangle(cornerRadius: 12)
                    .frame(width: 80, height: 80)
            }
        }
        .foregroundStyle(Color(.systemGray5))
        .padding()
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(radius: 3)
//        .opacity(animating ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animating)
        .onAppear { animating = true }
    }
}
