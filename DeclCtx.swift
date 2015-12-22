//
// DeclCtx.swift
//
// SwiSwi - a tiny Swift-like language
//
// Created for the Budapest Swift Meetup
// by Árpád Goretity (H2CO3)
// on 21/12/2015
//
// There's no warranty whatsoever.
//

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
