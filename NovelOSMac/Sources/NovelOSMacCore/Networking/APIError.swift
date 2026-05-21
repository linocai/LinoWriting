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
            APIError.httpUserMessage(status: status, body: body)
        case .decodingFailed(let reason):
            "后端数据解析失败：\(reason)"
        case .transport(let reason):
            "网络请求失败：\(reason)"
        case .missingResource(let name):
            "缺少必要数据：\(name)"
        }
    }

    private static func httpUserMessage(status: Int, body: String) -> String {
        let detail = detailMessage(from: body)
        switch status {
        case 401:
            return detail.map { "鉴权失败：\($0)" } ?? "鉴权失败：请检查 Owner Token。"
        case 404:
            return detail.map { "没有找到需要的数据：\($0)" } ?? "没有找到需要的数据。"
        case 409:
            return detail.map { "当前状态不能继续：\($0)" } ?? "当前状态不能继续，请先处理阻塞项。"
        case 502:
            return detail.map { "\($0) 可稍后重试。" } ?? "大模型或后端网关调用失败，可稍后重试。"
        case 503:
            return detail.map { "本地后端尚未准备好：\($0)" } ?? "本地后端尚未准备好，请检查服务是否启动。"
        default:
            return detail.map { "请求失败，HTTP \(status)：\($0)" }
                ?? (body.isEmpty ? "请求失败，HTTP \(status)。" : "请求失败，HTTP \(status)：\(body)")
        }
    }

    private static func detailMessage(from body: String) -> String? {
        guard let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return body.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
        if let detail = json["detail"] as? String {
            return detail
        }
        if let error = json["error"] as? [String: Any] {
            if let message = error["message"] as? String {
                return message
            }
            if let kind = error["kind"] as? String {
                return kind
            }
        }
        if let message = json["message"] as? String {
            return message
        }
        return nil
    }
}

extension APIError: LocalizedError {
    public var errorDescription: String? { userMessage }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
