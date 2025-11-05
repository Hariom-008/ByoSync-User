import SwiftUI

struct TransactionView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @State private var selectedPeriodType: PeriodType = .daily
    @State private var selectedReportType: ReportType = .view
    @State private var selectedDate: Date = Date()
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var customStartDate: Date = Date()
    @State private var customEndDate: Date = Date()

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "4B548D"), Color(hex: "3A4270")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: - Header Section
                headerSection
                
                // MARK: - Content Sheet
                VStack(spacing: 0) {
                    // Controls Section
                    controlsSection
                    
                    Divider()
                    
                    // MARK: - Success Message
                    if let successMessage = viewModel.successMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                            Text(successMessage)
                                .font(.subheadline)
                                .foregroundColor(.green)
                        }
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    
                    // MARK: - Content Area
                    contentArea
                }
                .background(Color.white)
                .cornerRadius(24, corners: [.topLeft, .topRight])
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .onAppear {
            fetchInitialData()
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
        .animation(.easeInOut(duration: 0.3), value: viewModel.transactions.count)
        .animation(.easeInOut(duration: 0.2), value: viewModel.successMessage)
        .onChange(of: viewModel.downloadedFileURL) { newValue in
            if let url = newValue {
                viewModel.shareFile(url: url)
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Top bar
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("transaction.title")
                        .font(.title).bold()
                        .foregroundColor(.white)
                    Text(viewModel.formattedDateDisplay(getDisplayDate()))
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // Summary cards
            HStack(spacing: 12) {
                CompactSummaryCard(
                    icon: "dollarsign.circle.fill",
                    title: String(localized: "transaction.total_paid"),
                    value: "₹\(String(format: "%.0f", viewModel.totalAmount))"
                )
                CompactSummaryCard(
                    icon: "doc.text.fill",
                    title: String(localized: "transaction.count"),
                    value: "\(viewModel.transactionCount)"
                )
                CompactSummaryCard(
                    icon: "gift.fill",
                    title: String(localized: "transaction.saved"),
                    value: "₹\(String(format: "%.2f", viewModel.discount))"
                )
            }
            .padding(.horizontal, 20)
        }
        .padding(.bottom, 24)
    }
    
    // MARK: - Controls Section
    private var controlsSection: some View {
        VStack(spacing: 16) {
            if selectedPeriodType == .custom {
                // Custom Period Layout (VStack arrangement)
                VStack(spacing: 12) {
                    // First Row: Filter and Fetch buttons
                    HStack(spacing: 12) {
                        // Filter Menu Button
                        filterMenuButton
                        
                        Spacer()
                        
                        // Fetch Button
                        fetchButton
                    }
                    
                    // Second Row: Date Pickers
                    datePickerCompact
                }
            } else {
                // Daily/Monthly Layout (HStack arrangement)
                HStack(spacing: 12) {
                    // Filter Menu Button
                    filterMenuButton
                    
                    // Date Picker (for Daily only)
                    if selectedPeriodType == .daily {
                        datePickerCompact
                    } else {
                        Spacer()
                    }
                    
                    // Fetch Button
                    fetchButton
                }
            }
        }
        .padding(20)
        .background(Color.white)
    }
    
    // MARK: - Filter Menu Button
    private var filterMenuButton: some View {
        Menu {
            // Period Type Section
            Section(header: Text("Period Type")) {
                Picker("Period", selection: $selectedPeriodType) {
                    ForEach(PeriodType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName)
                            .tag(type)
                    }
                }
            }
            
            // Report Type Section
            Section(header: Text("Report Type")) {
                Picker("Report", selection: $selectedReportType) {
                    ForEach(ReportType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName)
                            .tag(type)
                    }
                }
            }
            
            // Date Selection Section
            Section(header: Text("Date Selection")) {
                switch selectedPeriodType {
                case .monthly:
                    Menu {
                        Picker("Month", selection: $selectedMonth) {
                            ForEach(1...12, id: \.self) { month in
                                Text(monthName(month))
                                    .tag(month)
                            }
                        }
                    } label: {
                        Label("Month: \(monthName(selectedMonth))", systemImage: "calendar")
                    }
                    
                    Menu {
                        Picker("Year", selection: $selectedYear) {
                            ForEach(2020...Calendar.current.component(.year, from: Date()), id: \.self) { year in
                                Text(String(year))
                                    .tag(year)
                            }
                        }
                    } label: {
                        Label("Year: \(selectedYear)", systemImage: "calendar.badge.clock")
                    }
                default:
                    EmptyView()
                }
            }
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Filter")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(filterSummary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(hex: "F5F7FA"))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Fetch Button
    private var fetchButton: some View {
        Button(action: fetchData) {
            HStack(spacing: 4) {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.9)
                }
                Text(viewModel.isLoading ? "..." : selectedReportType.buttonText)
                    .font(.caption2)
                    .fontWeight(.regular)
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(width: 75)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color(hex: "4B548D"), Color(hex: "5E6BA8")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .shadow(color: Color(hex: "4B548D").opacity(0.3), radius: 6, y: 3)
        }
        .disabled(viewModel.isLoading)
    }
    
    // MARK: - Compact Date Picker
    @ViewBuilder
    private var datePickerCompact: some View {
        switch selectedPeriodType {
        case .daily:
            HStack(spacing: 8) {
                DatePicker(
                    "",
                    selection: $selectedDate,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .labelsHidden()
            }
            .padding(.horizontal, 12)
            .cornerRadius(12)
            
        case .custom:
            HStack(spacing: 10) {
                // Start Date
                HStack(spacing: 6) {
                    DatePicker(
                        "From",
                        selection: $customStartDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                
                Text("→")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // End Date
                HStack(spacing: 6) {
                    DatePicker(
                        "To",
                        selection: $customEndDate,
                        in: customStartDate...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            }
            .frame(maxWidth: .infinity)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Helper Computed Property
    private var filterSummary: String {
        "\(selectedPeriodType.displayName) • \(selectedReportType.displayName)"
    }
    
    // MARK: - Content Area
    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading {
            loadingView
        } else if let errorMessage = viewModel.errorMessage {
            errorView(message: errorMessage)
        } else if viewModel.transactions.isEmpty && selectedReportType == .view {
            emptyStateView
        } else if selectedReportType == .view {
            transactionListView
        } else {
            reportInfoView
        }
    }
    
    // MARK: - Loading View
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(Color(hex: "4B548D"))
            Text("transaction.processing_request")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    // MARK: - Error View
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("transaction.something_wrong")
                .font(.headline)
                .foregroundColor(.black.opacity(0.8))
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            Button(action: fetchData) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                    Text("transaction.try_again")
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(Color(hex: "4B548D"))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(hex: "4B548D"), lineWidth: 2)
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.fill")
                .font(.system(size: 56))
                .foregroundColor(.gray.opacity(0.3))
            
            Text("transaction.no_transactions")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.black.opacity(0.7))
            
            Text(String(format: String(localized: "transaction.no_transactions_for_date"), periodDisplayText))
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    // MARK: - Transaction List View
    private var transactionListView: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(viewModel.transactionCount) \(viewModel.transactionCount == 1 ? String(localized: "transaction.transaction") : String(localized: "transaction.transactions"))")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black.opacity(0.6))
                Spacer()
                Text(periodDisplayText)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemGray6))
            
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.getSortedTransactions()) { tx in
                        TransactionRow(tx: tx, discount: viewModel.calculateTransactionDiscount(tx.totalAmount))
                    }
                }
                .padding(20)
            }
            .background(Color.white)
        }
    }
    
    // MARK: - Report Info View
    private var reportInfoView: some View {
        VStack(spacing: 16) {
            Image(systemName: selectedReportType == .email ? "envelope.fill" : "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.3))
            
            Text(selectedReportType == .email ?
                 String(localized: "transaction.email_will_be_sent") :
                    String(localized: "transaction.report_will_be_downloaded"))
            .font(.subheadline)
            .foregroundColor(.gray)
            
            Text(String(format: String(localized: "transaction.click_to_proceed"), selectedReportType.buttonText))
                .font(.caption)
                .foregroundColor(.gray.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
    
    // MARK: - Helper Methods
    private func fetchInitialData() {
        fetchData()
    }
    
    private func fetchData() {
        switch selectedPeriodType {
        case .daily:
            viewModel.fetchTransactions(for: selectedDate, reportType: selectedReportType)
        case .monthly:
            viewModel.fetchMonthlyTransactions(
                month: selectedMonth,
                year: selectedYear,
                reportType: selectedReportType
            )
        case .custom:
            viewModel.fetchCustomTransactions(
                startDate: customStartDate,
                endDate: customEndDate,
                reportType: selectedReportType
            )
        }
    }
    
    private func getDisplayDate() -> Date {
        switch selectedPeriodType {
        case .daily:
            return selectedDate
        case .monthly, .custom:
            return Date()
        }
    }
    
    private var periodDisplayText: String {
        switch selectedPeriodType {
        case .daily:
            return viewModel.formattedDate(selectedDate)
        case .monthly:
            return "\(monthName(selectedMonth)) \(selectedYear)"
        case .custom:
            return "\(viewModel.formattedDate(customStartDate)) - \(viewModel.formattedDate(customEndDate))"
        }
    }
    
    private func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.monthSymbols = Calendar.current.monthSymbols
        return formatter.monthSymbols[month - 1]
    }
}

#Preview {
    TransactionView()
}
