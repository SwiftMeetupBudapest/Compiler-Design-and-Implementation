//
// Parser.swift
//
// SwiSwi - a tiny Swift-like language
//
// Created for the Budapest Swift Meetup
// by Árpád Goretity (H2CO3)
// on 28/10/2015
//
// There's no warranty whatsoever.
//

class Parser {
	var tokens: [Token]
	var cursor: Int
	var error: String?

	var location: SrcLoc {
		get { return cursor < tokens.count ? tokens[cursor].location : SrcLoc(0, 0) }
	}

	init(_ tokens: [Token]) {
		self.tokens = tokens
		self.cursor = 0
	}

	func eof() -> Bool {
		return cursor >= tokens.count
	}

	func isAtTokenString(str: String) -> Bool {
		return !eof() && tokens[cursor].value == str
	}

	func isAtTokenKind(kind: Token.Kind) -> Bool {
		return !eof() && tokens[cursor].kind == kind
	}

	func acceptTokenString(str: String) -> Token? {
		return isAtTokenString(str) ? tokens[cursor++] : nil
	}

	func acceptTokenKind(kind: Token.Kind) -> Token? {
		return isAtTokenKind(kind) ? tokens[cursor++] : nil
	}

	func acceptMulti(tokens: [String]) -> Token? {
		for token in tokens {
			if let tokenObj = acceptTokenString(token) {
				return tokenObj
			}
		}
		return nil
	}

	func acceptMultiMatcher(tokens: [String: (Token, AST) -> AST?])
		-> (Token, (Token, AST) -> AST?)?
	{
		for (token, parser) in tokens {
			if let tokenObj = acceptTokenString(token) {
				return (tokenObj, parser)
			}
		}
		return nil
	}

	func parse() -> AST? {
		return parseProgram()
	}

	//
	// Actual Parsers
	//

	// program := (funcDecl | funcDef) *
	func parseProgram() -> AST? {
		var children: [AST] = []

		while !eof() {
			if let fn = parseFunctionDeclOrDef() {
				children.append(fn)
			} else {
				return nil
			}
		}

		return ProgramAST(SrcLoc(1, 1), children)
	}

	func parseFuncParam() -> (String?, String?, Bool) {
		if isAtTokenString(")") {
			// empty parameter list
			return (nil, nil, true)
		}

		guard let paramName = acceptTokenKind(.Word) else {
			error = "expected empty parameter list or parameter name and type"
			return (nil, nil, false)
		}

		if paramName.isKeyword {
			error = "'\(paramName.value)' is a keyword, it can't be a parameter name"
			return (nil, nil, false)
		}

		if acceptTokenString(":") == nil {
			error = "expected ':' after parameter name"
			return (nil, nil, false)
		}

		guard let paramType = acceptTokenKind(.Word) else {
			error = "expected parameter type after ':'"
			return (nil, nil, false)
		}

		if paramType.isKeyword {
			error = "'\(paramType.value)' is a keyword, it can't be a type name"
			return (nil, nil, false)
		}

		return (paramName.value, paramType.value, true)
	}

	func parseReturnType() -> (String?, Bool) {
		if let _ = acceptTokenString("->") {
			// we've got an explicit return type
			guard let returnTypeTok = acceptTokenKind(.Word) else {
				error = "expected type name after '->'"
				return (nil, false)
			}

			if returnTypeTok.isKeyword {
				error = "\(returnTypeTok.value) is a keyword, it can't be a type name"
				return (nil, false)
			}

			return (returnTypeTok.value, true)
		}
		// no explicit return type
		return (nil, true)
	}

	// funcDecl := funcHead ';'
	// funcDef	:= funcHead block
	// funcHead := 'func' IDENT '(' (IDENT ':' IDENT)? ')' ('->' IDENT)?
	func parseFunctionDeclOrDef() -> AST? {
		guard let fn = acceptTokenString("func") else {
			error = "expected a function declaration or definition"
			return nil
		}

		guard let name = acceptTokenKind(.Word) else {
			error = "expected a function name"
			return nil
		}

		if name.isKeyword {
			error = "'\(name.value)' is a keyword, it can't be a function name"
			return nil
		}

		if acceptTokenString("(") == nil {
			error = "expected '(' after function name"
			return nil
		}

		let (paramName, paramType, pOK) = parseFuncParam()
		if !pOK {
			return nil
		}

		if acceptTokenString(")") == nil {
			error = "expected ')' after function parameter list"
			return nil
		}

		let (returnType, rOK) = parseReturnType()
		if !rOK {
			return nil
		}

		if let _ = acceptTokenString(";") {
			// just a declaration
			return FuncDeclAST(fn.location, name.value, paramName, paramType, returnType)
		}

		if let body = parseBlock() {
			return FuncDefAST(fn.location, name.value, paramName, paramType, returnType, body)
		}

		if error == nil {
			error = "expected ';' or block after function declaration/definition"
		}
		return nil
	}

	// statement := return | if | while | varDecl | block | exprStmt
	func parseStatement() -> AST? {
		let parsers = [
			"return": parseReturn,
			"if"	: parseIf,
			"while" : parseWhile,
			"var"	: parseVarDecl,
			"{"		: parseBlock
		]

		for (token, parser) in parsers {
			if isAtTokenString(token) {
				return parser()
			}
		}

		return parseExpressionStatement()
	}

	// return := 'return' expr? ';'
	func parseReturn() -> AST? {
		guard let ret = acceptTokenString("return") else {
			error = "expected 'return'"
			return nil
		}

		if acceptTokenString(";") != nil {
			return ReturnAST(ret.location)
		}

		guard let expr = parseExpression() else {
			return nil
		}

		if acceptTokenString(";") == nil {
			error = "expected ';' after returned expression"
			return nil
		}

		return ReturnAST(ret.location, expr)
	}

	// if := 'if' expr block ('else' (block | if))?
	func parseIf() -> AST? {
		guard let token = acceptTokenString("if") else {
			error = "expected 'if'"
			return nil
		}

		guard let cond = parseExpression() else {
			return nil
		}

		guard let thenBranch = parseBlock() else {
			return nil
		}

		var elseBranch: AST? = nil
		if acceptTokenString("else") != nil {
			elseBranch = isAtTokenString("if") ? parseIf() : parseBlock()
			if elseBranch == nil {
				return nil
			}
		}

		return IfThenElseAST(token.location, cond, thenBranch, elseBranch)
	}

	// while := 'while' expr block
	func parseWhile() -> AST? {
		guard let token = acceptTokenString("while") else {
			error = "expected 'while'"
			return nil
		}

		guard let cond = parseExpression() else {
			return nil
		}

		guard let body = parseBlock() else {
			return nil
		}

		return WhileLoopAST(token.location, cond, body)
	}

	// varDecl := 'var' IDENT '=' expr ';'
	func parseVarDecl() -> AST? {
		guard let token = acceptTokenString("var") else {
			error = "expected 'var'"
			return nil
		}

		guard let name = acceptTokenKind(.Word) else {
			error = "expected variable name"
			return nil
		}

		if name.isKeyword {
			error = "\"\(name.value)\" is a keyword, can't be a variable name"
			return nil
		}

		if acceptTokenString("=") == nil {
			error = "expected '=' (variable must be initialized)"
			return nil
		}

		guard let initExpr = parseExpression() else {
			return nil
		}

		if acceptTokenString(";") == nil {
			error = "expected ';' after initialzer expression"
			return nil
		}

		return VarDeclAST(token.location, name.value, initExpr)
	}

	// block := '{' (statement)* '}'
	func parseBlock() -> AST? {
		guard let lbrace = acceptTokenString("{") else {
			error = "expected '{' in block statement"
			return nil
		}

		var children: [AST] = []

		while acceptTokenString("}") == nil {
			if eof() {
				error = "expected '}' at end of block"
				return nil
			}

			if let child = parseStatement() {
				children.append(child)
			} else {
				return nil
			}
		}

		return BlockAST(lbrace.location, children)
	}

	// exprStmt := expr ';'
	func parseExpressionStatement() -> AST? {
		guard let expr = parseExpression() else {
			return nil
		}

		if acceptTokenString(";") == nil {
			error = "expected ';' after expression"
			return nil
		}

		return expr
	}

	// expr := assignment
	func parseExpression() -> AST? {
		return parseAssignment()
	}

	// assignment := or ('=' assignment)?
	func parseAssignment() -> AST? {
		return parseBinaryOpRightAssoc(["="], parseLogicalOr)
	}

	// or := or '||' and | and
	func parseLogicalOr() -> AST? {
		return parseBinaryOpLeftAssoc(["||"], parseLogicalAnd)
	}

	// and := and '&&' comparison | comparison
	func parseLogicalAnd() -> AST? {
		return parseBinaryOpLeftAssoc(["&&"], parseComparison)
	}

	// comparison := additive (comparisonOp additive)?
	// comparisonOp := '<' | '<=' | '>' | '>=' | '==' | '!='
	func parseComparison() -> AST? {
		return parseBinaryOpNoAssoc(
			["<", ">", "<=", ">=", "==", "!="],
			parseAdditive
		)
	}

	// additive := additive ('+' | '-') multiplicative | multiplicative
	func parseAdditive() -> AST? {
		return parseBinaryOpLeftAssoc(["+", "-"], parseMultiplicative)
	}

	// multiplicative := multiplicative ('*' | '/') prefix | prefix
	func parseMultiplicative() -> AST? {
		return parseBinaryOpLeftAssoc(["*", "/"], parsePrefix)
	}

	// prefix := ('+' | '-' | '!') prefix | postfix
	func parsePrefix() -> AST? {
		if let token = acceptMulti(["+", "-", "!"]) {
			guard let child = parsePrefix() else {
				return nil
			}

			return PrefixOpAST(token.location, token.value, child)
		} else {
			return parsePostfix()
		}
	}

	// postfix := call | subscript | term
	func parsePostfix() -> AST? {
		let matchers = [
			"(": parseFunctionCall,
			"[": parseSubscript
		]
		// t[i]()
		guard var ast = parseTerm() else {
			return nil
		}

		while let (token, parser) = acceptMultiMatcher(matchers) {
			guard let tmp = parser(token, ast) else {
				return nil
			}
			ast = tmp
		}

		return ast
	}
	
	// call := postfix '(' expr? ')'
	func parseFunctionCall(token: Token, _ function: AST) -> AST? {
		// function call with no parameters
		if acceptTokenString(")") != nil {
			return FuncCallAST(token.location, function)
		}

		// function call with parameter
		guard let parameter = parseExpression() else {
			return nil
		}

		if acceptTokenString(")") == nil {
			error = "expected ')' after function call parameter"
			return nil
		}

		return FuncCallAST(token.location, function, parameter)
	}

	// subscript := postfix '[' expr ']'
	func parseSubscript(token: Token, _ object: AST) -> AST? {
		// "[" already accepted, now parse an expression
		guard let subscriptExpr = parseExpression() else {
			return nil
		}

		if acceptTokenString("]") == nil {
			error = "expected ']' after subscript"
			return nil
		}

		return SubscriptAST(token.location, object, subscriptExpr)
	}

	// literals, stand-alone variables, parenthesized expressions
	// term := IDENT | INT | FLOAT | STRING | '(' expr ')'
	func parseTerm() -> AST? {
		// stand-alone identifier (function and variable name)
		if let word = acceptTokenKind(.Word) {
			if word.isKeyword {
				error = "\(word.value) is a keyword, it can't be a name"
				return nil
			}
			
			return IdentifierAST(word.location, word.value)
		}

		// integer or floating-point literal
		if let num = acceptTokenKind(.Number) {
			if num.value.rangeOfString(".") != nil {
				return FloatingLiteralAST(num.location, Double(num.value)!)
			} else {
				return IntegerLiteralAST(num.location, Int(num.value)!)
			}
		}

		// string literal
		if let str = acceptTokenKind(.StringLiteral) {
			return StringLiteralAST(str.location, str.value)
		}

		// parenthesized expression
		if acceptTokenString("(") != nil {
			guard let expr = parseExpression() else {
				return nil
			}

			if acceptTokenString(")") == nil {
				error = "unbalanced parentheses; expected ')'"
				return nil
			}

			return expr
		}

		error = (eof() ? "" : "invalid token: '\(tokens[cursor])'; ") + "expected a term"
		return nil
	}

	//
	// Helpers for parsing infix binary operators
	//
	func parseBinaryOpLeftAssoc(tokens: [String], _ subexpr: () -> AST?) -> AST? {
		guard var lhs = subexpr() else {
			return nil
		}

		while let op = acceptMulti(tokens) {
			guard let rhs = subexpr() else {
				return nil
			}

			let tmp = BinaryOpAST(op.location, op.value, lhs, rhs)
			lhs = tmp
		}

		return lhs
	}
	
	func parseBinaryOpRightAssoc(tokens: [String], _ subexpr: () -> AST?) -> AST? {
		guard let lhs = subexpr() else {
			return nil
		}

		if let op = acceptMulti(tokens) {
			guard let rhs = parseBinaryOpRightAssoc(tokens, subexpr) else {
				return nil
			}

			return BinaryOpAST(op.location, op.value, lhs, rhs)
		}

		return lhs
	}
	
	func parseBinaryOpNoAssoc(tokens: [String], _ subexpr: () -> AST?) -> AST? {
		guard let lhs = subexpr() else {
			return nil
		}

		if let op = acceptMulti(tokens) {
			guard let rhs = subexpr() else {
				return nil
			}

			return BinaryOpAST(op.location, op.value, lhs, rhs)
		}

		return lhs
	}
}
