//
// DCE.swift - AST-level Dead Code Elimination
//
// SwiSwi - a tiny Swift-like language
//
// Created for the Budapest Swift Meetup
// by Árpád Goretity (H2CO3)
// on 23/02/2016
//
// There's no warranty whatsoever.
//

func performDCEIfThenElse(ast: IfThenElseAST) -> AST {
	...
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
