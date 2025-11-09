//
//  GetUserRankBoardRepository.swift
//  ByoSync-User
//
//  Created by Hari's Mac on 08.11.2025.
//

import Foundation
import SwiftUI
import Alamofire
import Combine

struct LeaderboardAPIResponse: Codable {
    let statusCode: Int
    let data: [UserData]
    let message: String
}

final class GetUserRankBoardRepository {
    static let shared = GetUserRankBoardRepository()
    
    private init() {}
    
    func getUserRankBoard(completion: @escaping (Result<LeaderboardAPIResponse, APIError>) -> Void) {
        print("🌐 Fetching user rankboard from API...")
        let urlString = UserAPIEndpoint.Leaderboard.getRankboard
        let headers = getHeader.shared.getAuthHeaders()
        
        APIClient.shared.request(
            urlString,
            method: .get,
            parameters: nil,
            headers: headers,
            completion: completion
        )
    }
}

class GetUserRankViewModel: ObservableObject {
    @Published var users: [UserData] = []
    @Published var errorMessage: String = ""
    @Published var isLoading: Bool = false
    
    let getUserRank = GetUserRankBoardRepository.shared
    
    func fetchAllUsers() {
        print("📡 Starting to fetch all users for leaderboard...")
        isLoading = true
        
        getUserRank.getUserRankBoard { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let response):
                    print("✅ Successfully fetched \(response.data.count) users from leaderboard")
                    print("📊 Response: \(response.message)")
                    self?.users = response.data
                    
                    // Debug: Print top 3 users
                    let allUsers = response.data
                    for user in allUsers{
                        if user.id == UserSession.shared.currentUser?.userId{
                            UserSession.shared.wallet = user.wallet
                            print("👍 Latest Wallet Balance Fetched")
                        }
                    }
                    let topUsers = response.data.prefix(3)
                    for (index, user) in topUsers.enumerated() {
                        print("🏆 Top \(index + 1): \(user.firstName) \(user.lastName) - Transactions: \(user.noOfTransactions), Coins: \(user.transactionCoins)")
                    }
                    
                case .failure(let error):
                    print("❌ Failed to fetch leaderboard data")
                    print("❌ Error: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    // Get user rank by specific criteria
    func getUserRank(userId: String, sortBy: SortCriteria) -> Int? {
        let sortedUsers = getSortedUsers(by: sortBy)
        if let index = sortedUsers.firstIndex(where: { $0.id == userId }) {
            let rank = index + 1
            print("📍 User rank for \(userId): #\(rank) (sorted by \(sortBy))")
            return rank
        }
        print("⚠️ User \(userId) not found in leaderboard")
        return nil
    }
    
    // Get sorted users by criteria
    func getSortedUsers(by criteria: SortCriteria) -> [UserData] {
        switch criteria {
        case .transactions:
            return users.sorted { $0.noOfTransactions > $1.noOfTransactions }
        case .coins:
            return users.sorted { $0.transactionCoins > $1.transactionCoins }
        case .wallet:
            return users.sorted { $0.wallet > $1.wallet }
        }
    }
    
    enum SortCriteria {
        case transactions
        case coins
        case wallet
    }
}
