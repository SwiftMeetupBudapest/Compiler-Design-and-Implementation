struct DeclCtx {
	var globals: [String:TypeAnn]  // global variables
	var scopes: [[String:TypeAnn]] // local variables at function scope
	var functionRetType: TypeAnn?  // return type of function currently
	                               // being processed (used for checking
	                               // the type of return statements)

	var errmsg: String?
	var errnode: AST?

	init() {
		self.globals = [
			"false": BoolType(),
			"true": BoolType()
		]
		self.scopes = []
		self.functionRetType = nil
		self.errmsg = nil
		self.errnode = nil
	}
}
