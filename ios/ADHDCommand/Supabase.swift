import Foundation

// 輕量 PostgREST client — 與網頁版共用同一個 Supabase 專案與資料
enum Supabase {
    static let projectURL = URL(string: "https://ijzjwknrhjehskhrvvzr.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imlqemp3a25yaGplaHNraHJ2dnpyIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxMzY2MjQsImV4cCI6MjA5MzcxMjYyNH0.uCaE_oXUZkLWiZa4-xjLz5Q7Q99mr3D9LTx_TFraY3k"

    struct APIError: Error, LocalizedError {
        let status: Int
        let body: String
        var errorDescription: String? { "Supabase \(status): \(body)" }
    }

    @discardableResult
    static func request(
        _ table: String,
        method: String = "GET",
        query: [URLQueryItem] = [],
        json: [String: Any]? = nil,
        jsonArray: [[String: Any]]? = nil,
        prefer: String? = nil
    ) async throws -> Data {
        var comps = URLComponents(
            url: projectURL.appendingPathComponent("rest/v1/\(table)"),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { comps.queryItems = query }

        var req = URLRequest(url: comps.url!)
        req.httpMethod = method
        req.setValue(anonKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let prefer = prefer { req.setValue(prefer, forHTTPHeaderField: "Prefer") }
        if let json = json {
            req.httpBody = try JSONSerialization.data(withJSONObject: json)
        } else if let jsonArray = jsonArray {
            req.httpBody = try JSONSerialization.data(withJSONObject: jsonArray)
        }

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let status = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw APIError(status: status, body: String(data: data, encoding: .utf8) ?? "")
        }
        return data
    }

    // 便利方法：SELECT 並解碼
    static func select<T: Decodable>(
        _ table: String,
        as type: T.Type,
        order: String = "sort_order.asc,created_at.asc"
    ) async throws -> T {
        let data = try await request(table, query: [
            URLQueryItem(name: "select", value: "*"),
            URLQueryItem(name: "order", value: order),
        ])
        return try JSONDecoder().decode(T.self, from: data)
    }
}
