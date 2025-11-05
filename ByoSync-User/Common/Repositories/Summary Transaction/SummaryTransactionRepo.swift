//
//  SummaryTransactionRepo.swift
//  ByoSync
//
//  Created by Hari's Mac on 02.11.2025.
//

import Foundation
import SwiftUI
import Alamofire

final class SummaryTransactionRepository {
    static let shared = SummaryTransactionRepository()
    private init() {}
    
    // MARK: - Fetch Daily Summary
    func fetchDailySummary(
        date: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        let endpoint = CommonEndpoint.summaryTransactionData
        let parameters: [String: Any] = [
            "date": date,
            "type": "daily"
        ]
        
        let token = getHeader.shared.getAuthHeaders()
        
        let headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: parameters,
            headers: HTTPHeaders(headers)
        ) { (result: Result<SummaryTransactionResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch Monthly Summary
    func fetchMonthlySummary(
        month: String,
        year: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        let endpoint = CommonEndpoint.summaryTransactionData
        let parameters: [String: Any] = [
            "month": month,
            "year": year,
            "type": "monthly"
        ]
        
        let token = getHeader.shared.getAuthHeaders()
        
        let headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: parameters,
            headers: HTTPHeaders(headers)
        ) { (result: Result<SummaryTransactionResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch Custom Period Summary
    func fetchCustomSummary(
        startDate: String,
        endDate: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        let endpoint = CommonEndpoint.summaryTransactionData
        let parameters: [String: Any] = [
            "startDate": startDate,
            "endDate": endDate,
            "type": "custom"
        ]
        
        let token = getHeader.shared.getAuthHeaders()
        
        
        let headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: parameters,
            headers: HTTPHeaders(headers)
        ) { (result: Result<SummaryTransactionResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Fetch Weekly Summary
    func fetchWeeklySummary(
        startDate: String,
        endDate: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        fetchCustomSummary(startDate: startDate, endDate: endDate, completion: completion)
    }
    
    // MARK: - Fetch Yearly Summary
    func fetchYearlySummary(
        year: String,
        completion: @escaping (Result<SummaryTransactionData, APIError>) -> Void
    ) {
        let endpoint = CommonEndpoint.summaryTransactionData
        let parameters: [String: Any] = [
            "year": year,
            "type": "yearly"
        ]
        
        let token = getHeader.shared.getAuthHeaders()
        
        
        let headers = [
            "Authorization": "Bearer \(token)",
            "Content-Type": "application/json"
        ]
        
        APIClient.shared.request(
            endpoint,
            method: .post,
            parameters: parameters,
            headers: HTTPHeaders(headers)
        ) { (result: Result<SummaryTransactionResponse, APIError>) in
            switch result {
            case .success(let response):
                completion(.success(response.data))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
