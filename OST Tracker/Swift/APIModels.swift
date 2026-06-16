import Foundation

/// Auth response from `POST auth`.
struct AuthResponse: Decodable {
    let token: String
    let expiration: String?
}

/// Minimal JSON:API decoding for the OpenSplitTime responses. Only the
/// attributes we consume are declared; `Decodable` ignores the rest, so adding
/// a field later is a one-line change.
struct JSONAPIAttributes: Decodable {
    let name: String?       // eventGroups
    let baseName: String?   // splits
    let slug: String?       // eventGroups
    let fullName: String?   // efforts (present only when requested via fields[])
}

struct JSONAPIResource: Decodable {
    let id: String
    let type: String
    let attributes: JSONAPIAttributes
}

/// A list document: `{ "data": [ ... ] }`.
struct JSONAPIList: Decodable {
    let data: [JSONAPIResource]
}

/// A single-resource document with side-loaded resources:
/// `{ "data": {...}, "included": [ ... ] }`.
struct JSONAPIDoc: Decodable {
    let data: JSONAPIResource
    let included: [JSONAPIResource]

    enum CodingKeys: String, CodingKey { case data, included }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        data = try c.decode(JSONAPIResource.self, forKey: .data)
        included = (try? c.decode([JSONAPIResource].self, forKey: .included)) ?? []
    }
}
