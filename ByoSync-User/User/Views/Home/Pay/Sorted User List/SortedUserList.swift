//
//  SortedUserList.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 08.11.2025.
//

import Foundation
import SwiftUI

struct SortedUsersView: View {
    @StateObject private var viewModel = SortedUsersViewModel()
    @State private var searchText = ""
    @State private var showSearchBar = false
    @Binding var hideTabBar: Bool
    @Binding var amount: String
    @State private var selectedUser: UserData?
    @State private var openSelectedUserDetailsView: Bool = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                
                VStack(spacing: 0) {
                    if showSearchBar {
                        searchBarView
                    }
                    
                    contentView
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    searchButton
                }
            }
            .navigationDestination(isPresented: $openSelectedUserDetailsView) {
                if let user = selectedUser {
                    PaymentConfirmationView(
                        hideTabBar: $hideTabBar,
                        selectedUser: .constant(user),
                        amount: amount
                    )
                }
            }
            .task {
                await viewModel.fetchSortedUsers()
            }
            .alert("Error", isPresented: $viewModel.showError) {
                Button("Retry") {
                    Task {
                        await viewModel.retry()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred")
            }
        }
    }
    
    // MARK: - Background
    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(UIColor.systemGroupedBackground),
                Color(UIColor.secondarySystemGroupedBackground)
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // MARK: - Search Bar
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            
            TextField("Search by name, email or phone", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
            
            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private var searchButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3)) {
                showSearchBar.toggle()
                if !showSearchBar {
                    searchText = ""
                }
            }
        }) {
            Image(systemName: showSearchBar ? "xmark" : "magnifyingglass")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color(hex: "4B548D"))
        }
    }
    
    // MARK: - Content View
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isLoading {
            loadingView
        } else if viewModel.users.isEmpty {
            emptyStateView
        } else {
            usersList
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(hex: "4B548D"))
            
            Text("Loading users...")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("No Users Found")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)
            
            Text("There are no users available to send money to at the moment.")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button(action: {
                Task {
                    await viewModel.retry()
                }
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color(hex: "4B548D"))
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var usersList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filteredUsers) { user in
                    if UserSession.shared.currentUser?.userId != user.id{
                        UserCardView(user: user) {  // Pass the closure here
                            print("DEBUG: User selected - \(user.firstName) \(user.lastName)")
                            print("DEBUG: User ID - \(user.id)")
                            selectedUser = user
                            openSelectedUserDetailsView = true
                        }
                    }
                }
            }
            .padding()
        }
        .refreshable {
            await viewModel.fetchSortedUsers()
        }
    }
    
    
    private var filteredUsers: [UserData] {
        viewModel.filterUsers(by: searchText)
    }
}

// MARK: - User Card View
struct UserCardView: View {
    let user: UserData
    let onTap: () -> Void  // Add this closure
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 16) {
            profileImage
            userInfo
            Spacer()
            chevron
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        .scaleEffect(isPressed ? 0.97 : 1.0)
        .pressEvents(
            onPress: { isPressed = true },
            onRelease: {
                isPressed = false
                onTap()  // Call the tap action here
            }
        )
    }
    
    private var profileImage: some View {
        Group {
            if let url = URL(string: user.profilePic) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(width: 60, height: 60)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                    case .failure:
                        initialsView
                    @unknown default:
                        initialsView
                    }
                }
            } else {
                initialsView
            }
        }
    }
    
    private var initialsView: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "4B548D").opacity(0.15))
                .frame(width: 60, height: 60)
            
            Text(user.initials)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(Color(hex: "4B548D"))
        }
    }
    
    private var userInfo: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(user.firstName) \(user.lastName)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
            
            Text(user.email)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
    }
    
    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.gray.opacity(0.5))
    }
    
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.gray.opacity(0.1), lineWidth: 1)
            )
    }
}

// MARK: - Press Events View Modifier
extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.modifier(PressEventsModifier(onPress: onPress, onRelease: onRelease))
    }
}

struct PressEventsModifier: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in onPress() }
                    .onEnded { _ in onRelease() }
            )
    }
}
