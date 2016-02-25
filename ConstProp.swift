// If the AST represents a Boolean literal, return its value.
// Otherwise, return nil.
func boolLiteralValue(ast: AST) -> Bool? {
	guard let ident = ast as? IdentifierAST else {
		return nil
	}

	return ["false": false, "true": true][ident.name]
}

// Make an AST node representing a Boolean literal
func boolLiteralAST(loc: SrcLoc, _ b: Bool) -> IdentifierAST {
	let names = [false: "false", true: "true"]
	return IdentifierAST(loc, names[b]!)
}

func propagatePrefixOp(ast: PrefixOpAST) -> AST {
	let child = performConstProp(ast.child)

	if ast.op == "!" {
		if let b = boolLiteralValue(child) {
			return boolLiteralAST(ast.loc, !b)
		}
	}

	// don't know what to do - try propagating subexpression anyway
	ast.child = child
	return ast
}

// TODO: use identities to simplify partially-const expressions:
// true && rhs == rhs, false && rhs == false
// true || rhs == true, false || rhs == rhs
// and the same with the LHS
func propagateBinaryOp(ast: BinaryOpAST) -> AST {
	let lhs = performConstProp(ast.lhs)
	let rhs = performConstProp(ast.rhs)

	guard let bl = boolLiteralValue(lhs), br = boolLiteralValue(rhs) else {
		// 'ast' is not a literal per se, but let's not lose track of
		// its already-propagated subexpressions!
		ast.lhs = lhs
		ast.rhs = rhs
		return ast
	}

	switch ast.op {
	case "&&":
		return boolLiteralAST(ast.loc, bl && br)
	case "||":
		return boolLiteralAST(ast.loc, bl || br)
	default:
		// don't know what to do, just fall back to propagation of subexpressions
		ast.lhs = lhs
		ast.rhs = rhs
		return ast
	}
}

func propagateProgram(ast: ProgramAST) -> ProgramAST {
	ast.children = ast.children.map(performConstProp)
	return ast
}

func propagateBlock(ast: BlockAST) -> BlockAST {
	ast.children = ast.children.map(performConstProp)
	return ast
}

func propagateFuncDef(ast: FuncDefAST) -> FuncDefAST {
	ast.body = propagateBlock(ast.body)
	return ast
}

func propagateWhileLoop(ast: WhileLoopAST) -> WhileLoopAST {
	ast.condition = performConstProp(ast.condition)
	ast.body = propagateBlock(ast.body)
	return ast
}

func propagateIfThenElse(ast: IfThenElseAST) -> IfThenElseAST {
	ast.condition = performConstProp(ast.condition)
	ast.thenBranch = propagateBlock(ast.thenBranch)

	if let elseBranch = ast.elseBranch {
		ast.elseBranch = performConstProp(elseBranch)
	}

	return ast
}

func propagateVarDecl(ast: VarDeclAST) -> VarDeclAST {
	ast.initExpr = performConstProp(ast.initExpr)
	return ast
}

func propagateReturn(ast: ReturnAST) -> ReturnAST {
	if let expr = ast.expression {
		ast.expression = performConstProp(expr)
	}
	return ast
}

func propagateFuncCall(ast: FuncCallAST) -> FuncCallAST {
	ast.function = performConstProp(ast.function)

	if let param = ast.parameter {
		ast.parameter = performConstProp(param)
	}

	return ast
}

func performConstProp(ast: AST) -> AST {
	// For now, we'll focus on Booleans.
	// The same techniques apply to many other primitives as well.
	switch ast {
	case let binOp as BinaryOpAST:
		return propagateBinaryOp(binOp)
	case let prefixOp as PrefixOpAST:
		return propagatePrefixOp(prefixOp)
		// In the case of statements, try digging into their children of expression type.
	case let program as ProgramAST:
		return propagateProgram(program)
	case let block as BlockAST:
		return propagateBlock(block)
	case let funcDef as FuncDefAST:
		return propagateFuncDef(funcDef)
	case let whileLoop as WhileLoopAST:
		return propagateWhileLoop(whileLoop)
	case let ifThenElse as IfThenElseAST:
		return propagateIfThenElse(ifThenElse)
	case let varDecl as VarDeclAST:
		return propagateVarDecl(varDecl)
	case let returnAST as ReturnAST:
		return propagateReturn(returnAST)
	// case let subscriptAST as SubscriptAST:
	//	return propagateSubscript(subscriptAST)
	case let funcCall as FuncCallAST:
		return propagateFuncCall(funcCall)
	default:
		return ast
	}
}
