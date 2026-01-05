//
//  AddDeviceViewModel.swift
//

import Foundation
import Combine

@MainActor
final class AddDeviceViewModel: ObservableObject {

    enum State: Equatable {
        case idle
        case loading
        case success(message: String)
        case failure(message: String)
    }

    @Published private(set) var state: State = .idle

    private let repo: AddDeviceRepositoryProtocol

    init(repo: AddDeviceRepositoryProtocol = AddDeviceRepository.shared) {
        self.repo = repo
    }

    func reset() { state = .idle }

    func addDevice(
        deviceKey: String,
        deviceKeyHash: String,
        deviceName: String,
        deviceData: [String: AnyEncodable] = [:]
    ) {
        state = .loading

        let body = AddDeviceRequestBody(
            deviceKey: deviceKey,
            deviceKeyHash: deviceKeyHash,
            deviceName: deviceName,
            deviceData: deviceData
        )

        repo.addDevice(body: body) { [weak self] result in
            guard let self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let res):
                    let msg = res.message ?? "Success"
                    // Treat as success if success==true or statusCode==200
                    let ok = (res.success == true) || (res.statusCode == 200)
                    self.state = ok ? .success(message: msg) : .failure(message: msg)
                    
                   // UserDefaults.standard.set(res.data._id, forKey: "chaiDeviceId")
                    KeychainHelper.shared.save(res.data._id, forKey: "chaiDeviceId")

                case .failure(let err):
                    // No altered error class: just show what we have
                    self.state = .failure(message: err.localizedDescription)
                }
            }
        }
    }
}
