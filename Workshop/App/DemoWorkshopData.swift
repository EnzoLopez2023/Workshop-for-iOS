import Foundation
import NintekKit

/// A complete, local Workshop catalog for the signed-out demo. Production
/// screens use their normal `WorkshopAPI`; only the transport changes.
enum DemoWorkshopData {
    static let baseURL = URL(string: "https://workshop-demo.invalid")!
    static let userKey = "demo"

    private static let projectBaseId = 1_000
    private static let shaperBaseId = 2_000
    private static let projectImageBaseId = 5_000
    private static let shaperImageBaseId = 6_000
    private static let cutListBaseId = 10_000
    private static let materialBaseId = 20_000
    private static let createdAt = "2026-01-15T14:30:00.000Z"

    static func makeAPI() -> WorkshopAPI {
        WorkshopAPI(
            baseURL: baseURL,
            tokenProvider: StaticTokenProvider(nil),
            transport: DemoWorkshopTransport()
        )
    }

    static func isDemoURL(_ url: URL) -> Bool {
        url.host == baseURL.host
    }

    static func imageData(for url: URL) -> Data? {
        guard isDemoURL(url),
              let imageId = Int(url.lastPathComponent),
              let asset = imageAssets[imageId],
              let file = Bundle.main.url(forResource: asset, withExtension: "png")
        else { return nil }
        return try? Data(contentsOf: file)
    }

    static func responseData(for path: String) -> Data? {
        switch path {
        case "/api/projects":
            return json(projectRows)
        case "/api/shaper-projects":
            return json(shaperRows)
        case "/api/bambu-projects":
            return json([])
        case "/api/templates":
            return json([])
        case "/api/shopping-list":
            return json(shoppingRows)
        default:
            break
        }

        let parts = path.split(separator: "/")
        if parts.count == 4, parts[0] == "api", parts[1] == "projects",
           let id = Int(parts[2]), parts[3] == "cut-plan-config",
           projectIndex(for: id) != nil {
            return json(["config": NSNull()])
        }
        if parts.count == 3, parts[0] == "api", parts[1] == "projects",
           let id = Int(parts[2]), let index = projectIndex(for: id) {
            return json(projectDetail(index: index))
        }
        if parts.count == 3, parts[0] == "api", parts[1] == "shaper-projects",
           let id = Int(parts[2]), let index = shaperIndex(for: id) {
            return json(shaperDetail(index: index))
        }
        return nil
    }

    private static var projectRows: [[String: Any]] {
        StarterProjects.projects.enumerated().map { index, seed in
            let id = projectBaseId + index + 1
            let input = seed.input
            return [
                "id": id,
                "title": input.title,
                "description": nullable(input.description),
                "source_url": nullable(input.sourceUrl),
                "cut_plan_url": nullable(input.cutPlanUrl),
                "status": input.status.rawValue,
                "difficulty": input.difficulty.rawValue,
                "estimated_hours": input.estimatedHours,
                "wood_types": input.woodTypes,
                "tools_needed": input.toolsNeeded,
                "created_at": createdAt,
                "updated_at": updatedAt(index),
                "parts_count": seed.cutList.reduce(0) { $0 + $1.qty },
                "total_cost": seed.materials.reduce(0) { $0 + $1.cost },
                "hero_image_id": projectImageBaseId + index + 1,
                "cut_list_names": seed.cutList.map(\.partName).joined(separator: " "),
                "material_names": seed.materials.map(\.name).joined(separator: " "),
            ]
        }
    }

    private static func projectDetail(index: Int) -> [String: Any] {
        let seed = StarterProjects.projects[index]
        let input = seed.input
        let id = projectBaseId + index + 1
        let imageId = projectImageBaseId + index + 1
        let list = seed.cutList.enumerated().map { row, item in
            [
                "id": cutListBaseId + index * 100 + row + 1,
                "project_id": id,
                "part_name": item.partName,
                "qty": item.qty,
                "length": nullable(item.length),
                "width": nullable(item.width),
                "thickness": nullable(item.thickness),
                "material": nullable(item.material),
                "sort_order": item.sortOrder ?? row,
            ] as [String: Any]
        }
        let materials = seed.materials.enumerated().map { row, item in
            [
                "id": materialBaseId + index * 100 + row + 1,
                "project_id": id,
                "name": item.name,
                "qty_label": nullable(item.qtyLabel),
                "cost": item.cost,
                "purchased": false,
                "sort_order": item.sortOrder ?? row,
            ] as [String: Any]
        }
        return [
            "id": id,
            "title": input.title,
            "description": nullable(input.description),
            "source_url": nullable(input.sourceUrl),
            "cut_plan_url": nullable(input.cutPlanUrl),
            "status": input.status.rawValue,
            "difficulty": input.difficulty.rawValue,
            "estimated_hours": input.estimatedHours,
            "wood_types": input.woodTypes,
            "tools_needed": input.toolsNeeded,
            "images": [[
                "id": imageId,
                "project_id": id,
                "shaper_project_id": NSNull(),
                "kind": "sketch",
                "image_type": "image/png",
                "image_url": NSNull(),
                "sort_order": 0,
            ]],
            "cut_list": list,
            "materials": materials,
            "total_cost": seed.materials.reduce(0) { $0 + $1.cost },
            "parts_count": seed.cutList.reduce(0) { $0 + $1.qty },
            "build_log": [],
            "finish_log": [],
            "links": [],
            "created_at": createdAt,
            "updated_at": updatedAt(index),
        ]
    }

    private static var shaperRows: [[String: Any]] {
        StarterProjects.shaperProjects.enumerated().map { index, seed in
            let id = shaperBaseId + index + 1
            let input = seed.input
            return [
                "id": id,
                "title": input.title,
                "shaper_url": input.shaperUrl,
                "description": nullable(input.description),
                "photo_url": nullable(input.photoUrl),
                "materials": input.materials.map { ["name": $0.name, "qty": $0.qty] },
                "instructions": nullable(input.instructions),
                "hero_image_id": shaperImageBaseId + index + 1,
                "created_at": createdAt,
                "updated_at": updatedAt(index + StarterProjects.projects.count),
            ]
        }
    }

    private static func shaperDetail(index: Int) -> [String: Any] {
        let seed = StarterProjects.shaperProjects[index]
        let input = seed.input
        let id = shaperBaseId + index + 1
        let imageId = shaperImageBaseId + index + 1
        let list = seed.cutList.enumerated().map { row, item in
            [
                "id": cutListBaseId + 1_000 + index * 100 + row + 1,
                "project_id": NSNull(),
                "part_name": item.partName,
                "qty": item.qty,
                "length": nullable(item.length),
                "width": nullable(item.width),
                "thickness": nullable(item.thickness),
                "material": nullable(item.material),
                "sort_order": item.sortOrder ?? row,
            ] as [String: Any]
        }
        return [
            "id": id,
            "title": input.title,
            "shaper_url": input.shaperUrl,
            "description": nullable(input.description),
            "photo_url": nullable(input.photoUrl),
            "materials": input.materials.map { ["name": $0.name, "qty": $0.qty] },
            "instructions": nullable(input.instructions),
            "images": [[
                "id": imageId,
                "project_id": NSNull(),
                "shaper_project_id": id,
                "kind": "sketch",
                "image_type": "image/png",
                "image_url": NSNull(),
                "sort_order": 0,
            ]],
            "cut_list": list,
            "hero_image_id": imageId,
            "created_at": createdAt,
            "updated_at": updatedAt(index + StarterProjects.projects.count),
        ]
    }

    private static var shoppingRows: [[String: Any]] {
        StarterProjects.projects.enumerated().flatMap { projectIndex, seed in
            seed.materials.enumerated().map { row, item in
                [
                    "id": materialBaseId + projectIndex * 100 + row + 1,
                    "project_id": projectBaseId + projectIndex + 1,
                    "name": item.name,
                    "qty_label": nullable(item.qtyLabel),
                    "cost": item.cost,
                    "purchased": false,
                    "sort_order": item.sortOrder ?? row,
                    "project_title": seed.input.title,
                ] as [String: Any]
            }
        }
    }

    private static var imageAssets: [Int: String] {
        var result: [Int: String] = [:]
        for (index, seed) in StarterProjects.projects.enumerated() {
            result[projectImageBaseId + index + 1] = seed.planAsset
        }
        for (index, seed) in StarterProjects.shaperProjects.enumerated() {
            result[shaperImageBaseId + index + 1] = seed.planAsset
        }
        return result
    }

    private static func projectIndex(for id: Int) -> Int? {
        let index = id - projectBaseId - 1
        return StarterProjects.projects.indices.contains(index) ? index : nil
    }

    private static func shaperIndex(for id: Int) -> Int? {
        let index = id - shaperBaseId - 1
        return StarterProjects.shaperProjects.indices.contains(index) ? index : nil
    }

    private static func updatedAt(_ index: Int) -> String {
        String(format: "2026-01-%02dT14:30:00.000Z", 22 - index)
    }

    private static func nullable(_ value: String?) -> Any {
        guard let value, !value.isEmpty else { return NSNull() }
        return value
    }

    private static func json(_ object: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}

struct DemoWorkshopTransport: HTTPTransport {
    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else { throw URLError(.badURL) }
        let method = request.httpMethod ?? "GET"
        let status: Int
        let data: Data

        if method != "GET" {
            status = 403
            data = try JSONSerialization.data(withJSONObject: ["error": "Demo is read-only. Sign in to make changes."])
        } else if let response = DemoWorkshopData.responseData(for: url.path) {
            status = 200
            data = response
        } else {
            status = 404
            data = try JSONSerialization.data(withJSONObject: ["error": "Demo resource not found."])
        }

        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json; charset=utf-8"]
        )!
        return (data, response)
    }
}
