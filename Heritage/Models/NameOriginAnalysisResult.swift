import Foundation

struct NameOriginAnalysisResult: Codable, Equatable {
    var query: String
    var topCountries: [NameOriginCountryResult]
    var description: String

    static let placeholder = NameOriginAnalysisResult(
        query: "Volkov",
        topCountries: [
            NameOriginCountryResult(country: "Russia", countText: "1m", flagAssetName: "248-russia"),
            NameOriginCountryResult(country: "Belarus", countText: "300k", flagAssetName: "135-belarus"),
            NameOriginCountryResult(country: "Ukraine", countText: "50k", flagAssetName: "145-ukraine"),
            NameOriginCountryResult(country: "Kazakhstan", countText: "20k", flagAssetName: "074-kazakhstan"),
            NameOriginCountryResult(country: "Israel", countText: "15k", flagAssetName: "155-israel"),
        ],
        description: """
        The surname Volkov is a common Slavic last name with deep historical and cultural roots.

        Origin and Meaning

        The name Volkov comes from the Russian word "volk", which means "wolf." The suffix "-ov" indicates possession or belonging, so the surname can be translated as "son of the wolf" or "belonging to the wolf."

        Cultural Significance

        In Slavic cultures, the wolf has long been a powerful symbol. It is often associated with strength, courage, independence, resilience, cunning, and intelligence.

        Geographic Distribution

        The surname is especially common in Russia, Ukraine, Belarus, and other Eastern European countries.

        Summary

        Overall, Volkov reflects linguistic tradition and symbolic meaning, rooted in the image of the wolf as a strong and respected figure in Slavic folklore.
        """
    )
}

struct NameOriginCountryResult: Identifiable, Codable, Equatable {
    let country: String
    let countText: String
    let flagAssetName: String

    var id: String {
        country
    }
}
