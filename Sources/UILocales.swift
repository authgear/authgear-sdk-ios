public class UILocales {
    private init() {}

    static func stringify(uiLocales: [String]?) -> String {
        uiLocales?.joined(separator: " ") ?? ""
    }
}
