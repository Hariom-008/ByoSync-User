//
//  SortedUserRepository.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 08.11.2025.
//

import Foundation
import SwiftUI
import Combine
import Alamofire

// MARK: - Sorted Users Response
struct SortedUsersResponse: Codable {
    let statusCode: Int
    let data: [UserData]
    let message: String
}

class SortedUsersRepository {
    static let shared = SortedUsersRepository()
    
    private init() {}
    
    func fetchSortedUsers() async throws -> [UserData] {
        print("🔄 [SortedUsersRepo] Starting to fetch sorted users...")
        
        let urlString = UserAPIEndpoint.GetUserSorted.getUserSortedbyTransaction
        
        // Get auth headers
        let headers = getHeader.shared.getAuthHeaders()
        print("🔑 [SortedUsersRepo] Headers configured")
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request(
                urlString,
                method: .get,
                parameters: nil,
                headers: headers
            ) { (result: Result<SortedUsersResponse, APIError>) in
                switch result {
                case .success(let response):
                    print("✅ [SortedUsersRepo] Successfully fetched \(response.data.count) users")
                    continuation.resume(returning: response.data)
                    
                case .failure(let error):
                    print("❌ [SortedUsersRepo] Failed to fetch users: \(error.localizedDescription)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}


@MainActor
class SortedUsersViewModel: ObservableObject {
    @Published var users: [UserData] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    private let repository: SortedUsersRepository
    
    init(repository: SortedUsersRepository = .shared) {
        self.repository = repository
        print("🎬 [SortedUsersVM] ViewModel initialized")
    }
    
    /// Fetch sorted users from the API
    func fetchSortedUsers() async {
        print("🔄 [SortedUsersVM] Starting fetch...")
        isLoading = true
        errorMessage = nil
        showError = false
        
        do {
            // Fetch users from repository
            let fetchedUsers = try await repository.fetchSortedUsers()
            
            users = fetchedUsers
            isLoading = false
            print("✅ [SortedUsersVM] Successfully loaded \(fetchedUsers.count) users")
        } catch let error as APIError {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            print("❌ [SortedUsersVM] API Error: \(error.localizedDescription)")
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            showError = true
            print("❌ [SortedUsersVM] Unknown Error: \(error.localizedDescription)")
        }
    }
    
    /// Retry fetching users
    func retry() async {
        print("🔄 [SortedUsersVM] Retrying fetch...")
        await fetchSortedUsers()
    }
    
    /// Search/filter users by name
    func filterUsers(by searchText: String) -> [UserData] {
        if searchText.isEmpty {
            return users
        }
        let filtered = users.filter { user in
            user.firstName.lowercased().contains(searchText.lowercased()) ||
            user.email.lowercased().contains(searchText.lowercased()) ||
            user.phoneNumber.contains(searchText)
        }
        print("🔍 [SortedUsersVM] Filtered \(filtered.count) users for search: '\(searchText)'")
        return filtered
    }
    
    /// Clear all data
    func clearData() {
        users = []
        errorMessage = nil
        showError = false
        print("🗑️ [SortedUsersVM] Data cleared")
    }
}
