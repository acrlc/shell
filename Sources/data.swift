#if os(WASI) || os(Windows) || os(Linux)
import enum Crypto.Insecure
import FoundationNetworking
// https://medium.com/hoursofoperation/use-async-urlsession-with-server-side-swift-67821a64fa91
public enum URLSessionAsyncErrors: Error {
 case invalidUrlResponse, missingResponseData
}

public extension URLSession {
 func data(from url: URL) async throws -> (Data, URLResponse) {
  try await withCheckedThrowingContinuation { continuation in
   let task = self.dataTask(with: url) { data, response, error in
    if let error {
     continuation.resume(throwing: error)
     return
    }
    guard let response = response as? HTTPURLResponse else {
     continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
     return
    }
    guard let data else {
     continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
     return
    }
    continuation.resume(returning: (data, response))
   }
   task.resume()
  }
 }

 func data(for request: URLRequest) async throws -> (Data, URLResponse) {
  try await withCheckedThrowingContinuation { continuation in
   let task = self.dataTask(with: request) { data, response, error in
    if let error {
     continuation.resume(throwing: error)
     return
    }
    guard let response = response as? HTTPURLResponse else {
     continuation.resume(throwing: URLSessionAsyncErrors.invalidUrlResponse)
     return
    }
    guard let data else {
     continuation.resume(throwing: URLSessionAsyncErrors.missingResponseData)
     return
    }
    continuation.resume(returning: (data, response))
   }
   task.resume()
  }
 }
}

public extension Data {
 init(url: URL, session: URLSession = .shared) async throws {
  self = try await session.data(from: url).0
 }

 init(for request: URLRequest, session: URLSession = .shared) async throws {
  self = try await session.data(for: request).0
 }
}

#elseif os(iOS) || os(macOS)
@available(macOS 12, iOS 15, *)
public extension Data {
 @inlinable init(
  url: URL, session: URLSession = .shared,
  delegate: URLSessionTaskDelegate? = nil
 ) async throws {
  self = try await session.data(from: url, delegate: delegate).0
 }

 @inlinable init(
  for request: URLRequest, session: URLSession = .shared,
  delegate: URLSessionTaskDelegate? = nil
 ) async throws {
  self = try await session.data(for: request, delegate: delegate).0
 }
}
#endif
