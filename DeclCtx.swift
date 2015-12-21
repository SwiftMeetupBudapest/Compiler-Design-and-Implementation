struct DeclCtx {
    var globals: [String:TypeAnn]
    var scopes: [[String:TypeAnn]]

    init() {
        self.globals = [:]
        self.scopes = []
    }
}

