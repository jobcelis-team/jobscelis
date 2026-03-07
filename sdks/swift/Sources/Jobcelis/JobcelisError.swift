import Foundation

/// Error returned when the Jobcelis API returns an error.
public struct JobcelisError: Error, CustomStringConvertible {
    /// HTTP status code.
    public let statusCode: Int
    /// Error detail from the API response.
    public let detail: Any?

    public var description: String {
        "HTTP \(statusCode): \(String(describing: detail))"
    }
}
