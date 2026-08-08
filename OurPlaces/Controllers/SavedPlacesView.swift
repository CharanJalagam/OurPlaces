//
//  SavedPlacesView.swift
//  OurPlaces
//
//  Created by SAIRAM  on 21/03/26.
//

import SwiftUI


struct SavedPlacesView: View {
    
    @StateObject private var vm = SavedPlacesViewModel()
    
    var body: some View {
        ZStack {
            
            // MARK: - Content
            content
            
            // MARK: - Loader Overlay
            if vm.isLoading || vm.isDeleting {
                loaderView
            }
            
            // MARK: - Success Toast
            if vm.showSuccessToast {
                toastView
            }
        }
        .navigationTitle("Saved Locations")
        .task {
            await vm.fetchPlaces()
        }
        .alert("Delete Place?", isPresented: $vm.showDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await vm.deletePlace() }
            }
        } message: {
            Text("Are you sure you want to delete this place?")
        }
    }
}
extension SavedPlacesView {
    
    @ViewBuilder
    var content: some View {
        if vm.places.isEmpty && !vm.isLoading {
            emptyState
        } else {
            listView
        }
    }
}
extension SavedPlacesView {
    var emptyState: some View {
        VStack(spacing: 16) {
            
            Spacer()
            
            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange.opacity(0.7))
            
            Text("No places saved yet")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Start exploring the world and save the places that touch your heart.")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
        }
    }
}
extension SavedPlacesView {
    var listView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                Text("Your Collection")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("\(vm.places.count) places saved in total")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                
                ForEach(vm.places) { place in
                    placeCard(place)
                }
            }
            .padding()
        }
    }
}
extension SavedPlacesView {
    func placeCard(_ place: Place) -> some View {
        HStack {
            
            VStack(alignment: .leading, spacing: 6) {
                
                Text(place.category.uppercased())
                    .font(.caption)
                    .foregroundColor(.blue)
                
                Text(place.name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption)
                    Text(place.description ?? "")
                        .font(.subheadline)
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            Button {
                vm.selectedPlace = place
                vm.showDeleteAlert = true
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}
extension SavedPlacesView {
    var loaderView: some View {
        ZStack {
            Color.black.opacity(0.2).ignoresSafeArea()
            
            ProgressView()
                .scaleEffect(1.5)
        }
    }
}
extension SavedPlacesView {
    var toastView: some View {
        VStack {
            Spacer()
            
            Text(vm.successMessage)
                .padding()
                .background(Color.black.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(12)
                .padding(.bottom, 30)
        }
        .transition(.move(edge: .bottom))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    vm.showSuccessToast = false
                }
            }
        }
    }
}
