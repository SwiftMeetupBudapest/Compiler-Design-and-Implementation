func performDCEIfThenElse(ast: IfThenElseAST) -> AST {
	if let cond = ast.condition as? IdentifierAST {
		switch cond.name {
		case "true":
			// replace always-true 'if' by 'then' clause
			return ast.thenBranch
		case "false":
			// replace always-false 'if' by 'else' clause (if any), or by an empty statement otherwise
			if let elseBranch = ast.elseBranch {
				return elseBranch
			} else {
				return EmptyStmtAST(ast.loc)
			}
		default:
			break
		}
	}

	// recurse into children for dead code
	ast.thenBranch = performDCEBlock(ast.thenBranch)

	if let elseBranch = ast.elseBranch {
		ast.elseBranch = performDCE(elseBranch)
	}

	return ast
}

func performDCEWhileLoop(ast: WhileLoopAST) -> AST {
	// remove while loop with constant false condition
	if let cond = ast.condition as? IdentifierAST {
		if cond.name == "false" {
			// print("found dead loop body!")
			return EmptyStmtAST(ast.loc)
		}
	}

	// if the loop body itself is not dead, still search its children for dead code.
	ast.body = performDCEBlock(ast.body)
	return ast
}

func performDCEBlock(ast: BlockAST) -> BlockAST {
	ast.children = ast.children.map(performDCE)
	return ast
}

func performDCEProgram(ast: ProgramAST) -> ProgramAST {
	ast.children = ast.children.map(performDCE)
	return ast
}

func performDCEFunction(ast: FuncDefAST) -> FuncDefAST {
	ast.body = performDCEBlock(ast.body)
	return ast
}

func performDCE(ast: AST) -> AST {
	switch ast {
	case let program as ProgramAST:
		return performDCEProgram(program)
	case let block as BlockAST:
		return performDCEBlock(block)
	case let ifThenElse as IfThenElseAST:
		return performDCEIfThenElse(ifThenElse)
	case let whileLoop as WhileLoopAST:
		return performDCEWhileLoop(whileLoop)
	case let funcDef as FuncDefAST:
		return performDCEFunction(funcDef)
	default:
		return ast // other kinds of statements can't contain nested statements AND be at the top level at once
	}
}
