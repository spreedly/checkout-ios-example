//
//  PurchaseAPIClient.swift
//  SpreedlySDKExample
//
//  Created on [Date]
//

import Foundation
import SpreedlyCore

/// API client for purchase transactions
public class PurchaseAPIClient {

    /// Configuration for the purchase API server
    public struct ServerConfig {
        public let baseURL: String
        public let timeoutInterval: TimeInterval

        public init(
            baseURL: String,
            timeoutInterval: TimeInterval = 30.0
        ) {
            self.baseURL = baseURL
            self.timeoutInterval = timeoutInterval
        }
    }

    private let config: ServerConfig
    private let session: URLSession

    public init(config: ServerConfig) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.timeoutIntervalForRequest = config.timeoutInterval
        sessionConfig.timeoutIntervalForResource = config.timeoutInterval

        self.session = URLSession(configuration: sessionConfig)
    }

    /// Performs a purchase transaction
    /// - Parameters:
    ///   - paymentMethodToken: Token of the payment method to use
    ///   - amount: Purchase amount
    ///   - currencyCode: ISO 4217 currency code (e.g. "USD", "BRL")
    ///   - useGatewaySpecific3DS: When true, includes attempt_3dsecure in the request
    /// - Returns: PurchaseResponse with transaction token and 3DS metadata
    /// - Throws: PurchaseAPIError if the request fails
    public func purchase(
        paymentMethodToken: String,
        amount: Decimal,
        currencyCode: String,
        useGatewaySpecific3DS: Bool = false
    ) async throws -> PurchaseResponse {
        // URL: {baseURL}/purchase
        let trimmedBaseURL =
            config.baseURL.hasSuffix("/")
            ? String(config.baseURL.dropLast()) : config.baseURL
        guard let url = URL(string: "\(trimmedBaseURL)/purchase") else {
            throw PurchaseAPIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue("*/*", forHTTPHeaderField: "accept")

        do {
            let encoder = JSONEncoder()
            // No key encoding strategy needed - using explicit CodingKeys
            if useGatewaySpecific3DS {
                let request = GatewaySpecificPurchaseTransactionRequest(
                    amount: amount,
                    currencyCode: currencyCode,
                    paymentMethodToken: paymentMethodToken
                )
                urlRequest.httpBody = try encoder.encode(request)
            } else {
                let request = PurchaseTransactionRequest(
                    amount: amount,
                    currencyCode: currencyCode,
                    paymentMethodToken: paymentMethodToken
                )
                urlRequest.httpBody = try encoder.encode(request)
            }
        } catch {
            throw PurchaseAPIError.encodingError(error)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PurchaseAPIError.invalidResponse
            }

            if !(200...202).contains(httpResponse.statusCode) {
                let errorMessage = APIResponseErrorParser.extractMessage(from: data)
                throw PurchaseAPIError.serverError(
                    httpResponse.statusCode,
                    data,
                    errorMessage: errorMessage
                )
            }

            do {
                return try JSONDecoder().decode(PurchaseResponse.self, from: data)
            } catch {
                throw PurchaseAPIError.encodingError(error)
            }

        } catch let error as PurchaseAPIError {
            throw error
        } catch {
            throw PurchaseAPIError.networkError(error)
        }
    }

    /// Performs an offsite purchase via merchant backend (same pattern as 3DS purchase).
    /// - Parameters:
    ///   - gateway: Offsite gateway identifier; use "sprel" for Sprel, "paypal" for PayPal
    ///   - paymentMethodToken: Token of the payment method to use
    ///   - amount: Purchase amount (in cents)
    ///   - currencyCode: ISO 4217 currency code (e.g. "USD", "BRL")
    ///   - redirectUrl: Redirect URL for offsite flow
    ///   - callbackUrl: Callback URL for offsite flow
    /// - Returns: PurchaseResponse (same as purchase)
    /// - Throws: PurchaseAPIError if the request fails
    public func offsitePurchase(
        gateway: String,
        paymentMethodToken: String,
        amount: Decimal,
        currencyCode: String,
        redirectUrl: String,
        callbackUrl: String
    ) async throws -> PurchaseResponse {
        let trimmedBaseURL =
            config.baseURL.hasSuffix("/")
            ? String(config.baseURL.dropLast()) : config.baseURL
        guard let url = URL(string: "\(trimmedBaseURL)/offsite-purchase") else {
            throw PurchaseAPIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("*/*", forHTTPHeaderField: "accept")

        let request = OffsitePurchaseRequest(
            gateway: gateway,
            amount: amount,
            currencyCode: currencyCode,
            paymentMethodToken: paymentMethodToken,
            redirectUrl: redirectUrl,
            callbackUrl: callbackUrl,
            channel: "app"
        )
        do {
            urlRequest.httpBody = try JSONEncoder().encode(request)
        } catch {
            throw PurchaseAPIError.encodingError(error)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PurchaseAPIError.invalidResponse
        }

        if !(200...202).contains(httpResponse.statusCode) {
            let errorMessage = APIResponseErrorParser.extractMessage(from: data)
            throw PurchaseAPIError.serverError(httpResponse.statusCode, data, errorMessage: errorMessage)
        }

        return try JSONDecoder().decode(PurchaseResponse.self, from: data)
    }

    // MARK: - Heroku create-purchase (Stripe: gateway "stripe", payment_method with stripe_apm + apm_types; channel "app")
    public func stripeAPMPendingPurchase(
        amount: Decimal,
        currencyCode: String,
        redirectUrl: String,
        callbackUrl: String,
        apmTypes: [String]
    ) async throws -> PurchaseResponse {
        let paymentMethod = StripeAPMPaymentMethod(apmTypes: apmTypes)
        let transaction = HerokuCreatePurchaseTransaction(
            paymentMethodToken: nil,
            amount: amount,
            currencyCode: currencyCode,
            redirectUrl: redirectUrl,
            callbackUrl: callbackUrl,
            channel: "app",
            paymentMethod: paymentMethod
        )
        let body = HerokuCreatePurchaseRequest(gateway: "stripe", transaction: transaction)
        return try await postHeroku(path: "create-purchase", body: body)
    }

    /// Heroku Braintree purchase: POST braintree-purchase (flat body + channel "app")
    public func braintreePurchase(
        amount: Decimal,
        currencyCode: String,
        redirectUrl: String,
        callbackUrl: String,
        paymentMethodType: String
    ) async throws -> PurchaseResponse {
        let body = HerokuBraintreePurchaseRequest(
            amount: amount,
            currencyCode: currencyCode,
            redirectUrl: redirectUrl,
            callbackUrl: callbackUrl,
            channel: "app",
            paymentMethodType: paymentMethodType
        )
        return try await postHeroku(path: "braintree-purchase", body: body)
    }

    /// Heroku Braintree confirm: POST transactions/{token}/confirm (no device_data)
    public func braintreeConfirm(
        transactionToken: String,
        state: String,
        nonce: String,
        paymentMethodType: String
    ) async throws -> PurchaseResponse {
        let body = HerokuConfirmRequest(state: state, nonce: nonce, paymentMethodType: paymentMethodType)
        return try await postHeroku(path: "transactions/\(transactionToken)/confirm", body: body)
    }

    /// Heroku create-purchase (EBANX: gateway "ebanx", with payment_method_token; channel "app")
    public func ebanxPurchase(
        paymentMethodToken: String,
        amount: Decimal,
        currencyCode: String,
        redirectUrl: String,
        callbackUrl: String
    ) async throws -> PurchaseResponse {
        let transaction = HerokuCreatePurchaseTransaction(
            paymentMethodToken: paymentMethodToken,
            amount: amount,
            currencyCode: currencyCode,
            redirectUrl: redirectUrl,
            callbackUrl: callbackUrl,
            channel: "app"
        )
        let body = HerokuCreatePurchaseRequest(gateway: "ebanx", transaction: transaction)
        return try await postHeroku(path: "create-purchase", body: body)
    }

    private func postHeroku<T: Encodable>(path: String, body: T) async throws -> PurchaseResponse {
        let trimmedBaseURL = config.baseURL.hasSuffix("/") ? String(config.baseURL.dropLast()) : config.baseURL
        guard let url = URL(string: "\(trimmedBaseURL)/\(path)") else {
            throw PurchaseAPIError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("*/*", forHTTPHeaderField: "accept")
        do {
            urlRequest.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw PurchaseAPIError.encodingError(error)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw PurchaseAPIError.invalidResponse
        }

        if !(200...202).contains(httpResponse.statusCode) {
            let errorMessage = APIResponseErrorParser.extractMessage(from: data)
            throw PurchaseAPIError.serverError(httpResponse.statusCode, data, errorMessage: errorMessage)
        }
        return try JSONDecoder().decode(PurchaseResponse.self, from: data)
    }

    /// Completes a 3DS transaction via complete.json endpoint
    /// - Parameter transactionToken: Token of the transaction to complete
    /// - Returns: TransactionCompleteResponse with updated transaction status
    /// - Throws: PurchaseAPIError if the request fails
    public func complete(transactionToken: String) async throws
        -> TransactionCompleteResponse
    {
        // URL: {baseURL}/transactions/{transaction_token}/complete
        let trimmedBaseURL =
            config.baseURL.hasSuffix("/")
            ? String(config.baseURL.dropLast()) : config.baseURL
        guard
            let url = URL(
                string:
                    "\(trimmedBaseURL)/transactions/\(transactionToken)/complete"
            )
        else {
            throw PurchaseAPIError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        urlRequest.setValue("*/*", forHTTPHeaderField: "accept")

        do {
            let (data, response) = try await session.data(for: urlRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw PurchaseAPIError.invalidResponse
            }

            if !(200...202).contains(httpResponse.statusCode) {
                let errorMessage = APIResponseErrorParser.extractMessage(from: data)
                throw PurchaseAPIError.serverError(
                    httpResponse.statusCode,
                    data,
                    errorMessage: errorMessage
                )
            }

            do {
                return try JSONDecoder().decode(TransactionCompleteResponse.self, from: data)
            } catch {
                throw PurchaseAPIError.encodingError(error)
            }

        } catch let error as PurchaseAPIError {
            throw error
        } catch {
            throw PurchaseAPIError.networkError(error)
        }
    }
}

// MARK: - Error Handling
public enum PurchaseAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case serverError(Int, Data, errorMessage: String? = nil)
    case networkError(Error)
    case encodingError(Error)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid purchase API URL"
        case .invalidResponse:
            return "Invalid response from purchase API"
        case .serverError(let statusCode, let data, let errorMessage):
            // Use parsed error message if available, otherwise fallback to raw data
            if let errorMessage = errorMessage, !errorMessage.isEmpty {
                return errorMessage
            } else {
                // Fallback to raw data if message parsing failed
                let rawErrorMessage =
                    String(data: data, encoding: .utf8) ?? "Unknown error"
                return "Purchase API error (\(statusCode)): \(rawErrorMessage)"
            }
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Encoding error: \(error.localizedDescription)"
        }
    }

    /// Extracts the error message from the error, prioritizing parsed message over raw data
    public var message: String? {
        switch self {
        case .serverError(_, _, let errorMessage):
            return errorMessage
        default:
            return errorDescription
        }
    }
}
