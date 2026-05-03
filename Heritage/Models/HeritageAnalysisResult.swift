import Foundation

struct HeritageAnalysisResult: Codable, Equatable {
    var origins: [HeritageOriginResult]
    var surname: String
    var surnameDescription: String

    static let placeholder = HeritageAnalysisResult(
        origins: [
            HeritageOriginResult(country: "Russia", percentage: 50, flagAssetName: "248-russia"),
            HeritageOriginResult(country: "Belarus", percentage: 25, flagAssetName: "135-belarus"),
            HeritageOriginResult(country: "Ukraine", percentage: 10, flagAssetName: "145-ukraine"),
            HeritageOriginResult(country: "Kazakhstan", percentage: 10, flagAssetName: "074-kazakhstan"),
            HeritageOriginResult(country: "Israel", percentage: 5, flagAssetName: "155-israel"),
        ],
        surname: "Volkov",
        surnameDescription: """
        The surname Volkov is a common Slavic last name with deep historical and cultural roots.

        Origin and Meaning

        The name Volkov comes from the Russian word "volk", which means "wolf." The suffix "-ov" indicates possession or belonging, so the surname can be translated as "son of the wolf" or "belonging to the wolf."

        Cultural Significance

        In Slavic cultures, the wolf has long been a powerful symbol. It is often associated with strength, courage, independence, resilience, cunning, and intelligence.

        Geographic Distribution

        The surname is especially common in Russia, Ukraine, Belarus, and other Eastern European countries.

        Summary

        Overall, Volkov is a surname that reflects both linguistic tradition and symbolic meaning, rooted in the image of the wolf as a strong and respected figure in Slavic folklore.
        """
    )
}

struct HeritageOriginResult: Identifiable, Codable, Equatable {
    let country: String
    let percentage: Int
    let flagAssetName: String

    var id: String {
        country
    }

    var percentText: String {
        "\(percentage)%"
    }

    static func normalizedTopFive(_ origins: [HeritageOriginResult]) -> [HeritageOriginResult] {
        let topFive = Array(origins.prefix(5))

        guard topFive.count == 5 else {
            return topFive
        }

        let clamped = topFive.map {
            HeritageOriginResult(
                country: $0.country,
                percentage: max(0, min(100, $0.percentage)),
                flagAssetName: $0.flagAssetName
            )
        }
        let total = clamped.reduce(0) { $0 + $1.percentage }

        guard total > 0 else {
            return clamped.enumerated().map { index, origin in
                HeritageOriginResult(
                    country: origin.country,
                    percentage: index == 4 ? 20 : 20,
                    flagAssetName: origin.flagAssetName
                )
            }
        }

        var normalized: [HeritageOriginResult] = []
        var used = 0

        for (index, origin) in clamped.enumerated() {
            let percentage: Int
            if index == clamped.count - 1 {
                percentage = max(0, 100 - used)
            } else {
                percentage = Int((Double(origin.percentage) / Double(total) * 100).rounded())
                used += percentage
            }

            normalized.append(
                HeritageOriginResult(
                    country: origin.country,
                    percentage: percentage,
                    flagAssetName: origin.flagAssetName
                )
            )
        }

        return normalized
    }
}

struct HeritageAnalysisInput {
    let fullName: String
    let gender: String
    let birthMonth: String
    let birthDay: Int
    let birthYear: Int

    var surname: String {
        let parts = fullName
            .split(separator: " ")
            .map(String.init)

        return parts.last ?? ""
    }
}

enum CountryFlagAssets {
    static let fallback = "082-united-nations"

    private static let countryToAsset = [
        "afghanistan": "111-afghanistan",
        "algeria": "144-algeria",
        "argentina": "198-argentina",
        "armenia": "108-armenia",
        "australia": "234-australia",
        "austria": "003-austria",
        "azerbaijan": "141-azerbaijan",
        "bangladesh": "147-bangladesh",
        "belarus": "135-belarus",
        "belgium": "165-belgium",
        "brazil": "255-brazil",
        "bulgaria": "168-bulgaria",
        "canada": "243-canada",
        "chile": "131-chile",
        "china": "034-china",
        "colombia": "177-colombia",
        "croatia": "164-croatia",
        "cuba": "153-cuba",
        "czech republic": "149-czech-republic",
        "denmark": "174-denmark",
        "egypt": "158-egypt",
        "england": "216-england",
        "estonia": "008-estonia",
        "ethiopia": "005-ethiopia",
        "finland": "125-finland",
        "france": "195-france",
        "georgia": "256-georgia",
        "germany": "162-germany",
        "ghana": "053-ghana",
        "greece": "170-greece",
        "hungary": "115-hungary",
        "india": "246-india",
        "indonesia": "209-indonesia",
        "iran": "136-iran",
        "iraq": "020-iraq",
        "ireland": "179-ireland",
        "israel": "155-israel",
        "italy": "013-italy",
        "japan": "063-japan",
        "kazakhstan": "074-kazakhstan",
        "kenya": "067-kenya",
        "kyrgyzstan": "152-kyrgyzstan",
        "latvia": "044-latvia",
        "lebanon": "018-lebanon",
        "lithuania": "064-lithuania",
        "mexico": "252-mexico",
        "moldova": "212-moldova",
        "morocco": "166-morocco",
        "netherlands": "237-netherlands",
        "new zealand": "121-new-zealand",
        "nigeria": "086-nigeria",
        "norway": "143-norway",
        "pakistan": "100-pakistan",
        "peru": "188-peru",
        "philippines": "192-philippines",
        "poland": "211-poland",
        "puerto rico": "028-puerto-rico",
        "romania": "109-romania",
        "russia": "248-russia",
        "scotland": "055-scotland",
        "serbia": "071-serbia",
        "slovakia": "091-slovakia",
        "south africa": "200-south-africa",
        "south korea": "094-south-korea",
        "spain": "128-spain",
        "sweden": "184-sweden",
        "switzerland": "205-switzerland",
        "syria": "022-syria",
        "tajikistan": "196-tajikistan",
        "thailand": "238-thailand",
        "tunisia": "049-tunisia",
        "turkey": "218-turkey",
        "turkmenistan": "229-turkmenistan",
        "ukraine": "145-ukraine",
        "united arab emirates": "151-united-arab-emirates",
        "united kingdom": "260-united-kingdom",
        "uzbekistan": "190-uzbekistn",
        "venezuela": "139-venezuela",
        "vietnam": "220-vietnam",
        "wales": "014-wales",
    ]

    static var promptChoices: String {
        countryToAsset
            .sorted { $0.key < $1.key }
            .map { "\($0.key.capitalized) => \($0.value)" }
            .joined(separator: ", ")
    }

    static func assetName(for country: String, suggestedAssetName: String?) -> String {
        if let suggestedAssetName,
           countryToAsset.values.contains(suggestedAssetName)
        {
            return suggestedAssetName
        }

        let key = normalized(country)
        return countryToAsset[key] ?? fallback
    }

    private static func normalized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }
}
