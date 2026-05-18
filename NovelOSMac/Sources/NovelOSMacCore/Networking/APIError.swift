import Foundation

public enum APIError: Error, Equatable, Sendable {
    case invalidBaseURL(String)
    case requestEncodingFailed(String)
    case invalidResponse
    case httpStatus(Int, String)
    case decodingFailed(String)
    case transport(String)
    case missingResource(String)

    public var userMessage: String {
        switch self {
        case .invalidBaseURL(let value):
            "API 地址无效：\(value)"
        case .requestEncodingFailed(let reason):
            "请求数据编码失败：\(reason)"
        case .invalidResponse:
            "后端返回了无法识别的响应。"
        case .httpStatus(let status, let body):
            body.isEmpty ? "请求失败，HTTP \(status)。" : "请求失败，HTTP \(status)：\(body)"
        case .decodingFailed(let reason):
            "后端数据解析失败：\(reason)"
        case .transport(let reason):
            "网络请求失败：\(reason)"
        case .missingResource(let name):
            "缺少必要数据：\(name)"
        }
    }
}

extension APIError: LocalizedError {
    public var errorDescription: String? { userMessage }
}
