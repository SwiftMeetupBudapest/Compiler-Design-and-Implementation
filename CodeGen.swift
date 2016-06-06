//
// CodeGen.swift
//
// SwiSwi - a tiny Swift-like language
//
// Created for the Budapest Swift Meetup
// by Árpád Goretity (H2CO3)
// on 23/12/2015
//
// There's no warranty whatsoever.
//

struct RetAndArgTypes {
    let returnType: LLVMTypeRef
    let argumentTypes: [LLVMTypeRef]

    init(_ returnType: LLVMTypeRef, _ argumentTypes: LLVMTypeRef...) {
        self.returnType = returnType
        self.argumentTypes = argumentTypes
    }
}

class CodeGen {
	// we don't need a 'globals' table: global variables and functions
	// can be obtained directly from the module.

	// the stack of local variables
	var scopes: [[String: LLVMValueRef]]

	var errmsg: String?
	var errnode: AST?

	var module: LLVMModuleRef // non-owning pointer
	var builder: LLVMBuilderRef

	// a stack of nested functions - the last one is the innermost.
	// Necessary for appending basic blocks
	// (when compiling branches and loops)
	var functions: [LLVMValueRef]

	init() {
		self.scopes = []
		self.errmsg = nil
		self.errnode = nil
		self.module = nil
		self.builder = LLVMCreateBuilder()
		self.functions = []
	}

	deinit {
		LLVMDisposeBuilder(self.builder)
		self.module = nil // just in case
	}

	// searches for a local variable
	func getLocal(name: String) -> LLVMValueRef? {
		for scope in self.scopes.reverse() {
			if let value = scope[name] {
				return value
			}
		}
		return nil
	}

	// Adds declarations of built-in runtime functions to the module
	func declareBuiltInFunctions(module: LLVMModuleRef) {
      func get_fntype(retType: LLVMTypeRef, _ argTypes: [LLVMTypeRef]) -> LLVMTypeRef {
          var argTypes = argTypes
          return LLVMFunctionType(retType, &argTypes, CUnsignedInt(argTypes.count), 0)
      }

      let builtins = [
          "__string_literal": RetAndArgTypes(StringType().llvmType(), LLVMPointerType(LLVMInt8Type(), 0)),
          "__string_destroy": RetAndArgTypes(LLVMVoidType(), LLVMPointerType(StringType().llvmType(), 0))
      ]

      for (name, types) in builtins {
		      LLVMAddFunction(module, name, get_fntype(types.returnType, types.argumentTypes))
      }
	}

  func callDestructors(scope: [String:LLVMValueRef]) {
  }

	// returns: value of expression on success; null pointer (nil) on error
	func codegenExpr(ast: AST) -> LLVMValueRef {
		switch ast {
		case let intLiteral as IntegerLiteralAST:
			return codegenIntegerLiteral(intLiteral)
		case let floatLiteral as FloatingLiteralAST:
			return codegenFloatingLiteral(floatLiteral)
		case let stringLiteral as StringLiteralAST:
			return codegenStringLiteral(stringLiteral)
		case let ident as IdentifierAST:
			return codegenIdentifier(ident)
		case let binOp as BinaryOpAST:
			return codegenBinaryOp(binOp)
		case let prefixOp as PrefixOpAST:
			return codegenPrefixOp(prefixOp)
		// case let subscr as SubscriptAST:
		//	   return codegenSubscript(subscr)
		case let call as FuncCallAST:
			return codegenFuncCall(call)
		default:
			self.errmsg = "unrecognized expression (?) node: \(ast)"
			self.errnode = ast
			return nil
		}
	}

	func codegenStmt(ast: AST) {
		switch ast {
		// def needs to go before decl since def is a subtype of decl
		// (so the reverse order would catch everything as a declaration
		// early, even definitions...)
		case let funcDef as FuncDefAST:
			self.codegenFuncDef(funcDef)
		case let funcDecl as FuncDeclAST:
			self.codegenFuncDecl(funcDecl)
		case let block as BlockAST:
			self.codegenBlock(block)
		case let ret as ReturnAST:
			self.codegenReturn(ret)
		case let ifThenElse as IfThenElseAST:
			self.codegenIfThenElse(ifThenElse)
		case let whileLoop as WhileLoopAST:
			self.codegenWhileLoop(whileLoop)
		case let varDecl as VarDeclAST:
			self.codegenVarDecl(varDecl)
		case let _ as EmptyStmtAST:
			// do nothing
			break
		default: // wasn't a non-expression statement; assume an expression
			self.codegenExpr(ast)
		}
	}

	//
	// Codegen functions for expressions
	//
	func codegenIntegerLiteral(ast: IntegerLiteralAST) -> LLVMValueRef {
		// 1: true, sign-extend
		return LLVMConstInt(ast.typeAnn!.llvmType(), CUnsignedLongLong(ast.value), 1)
	}

	func codegenFloatingLiteral(ast: FloatingLiteralAST) -> LLVMValueRef {
		return LLVMConstReal(ast.typeAnn!.llvmType(), ast.value)
	}

	func codegenStringLiteral(ast: StringLiteralAST) -> LLVMValueRef {
		let stringPtr = LLVMBuildGlobalStringPtr(self.builder, ast.value, "str.raw")
		let fn = LLVMGetNamedFunction(self.module, "__string_literal")
		var args = [ stringPtr ]
		return LLVMBuildCall(self.builder, fn, &args, CUnsignedInt(args.count), "str.obj")
	}

	func codegenIdentifier(ast: IdentifierAST) -> LLVMValueRef {
		switch ast.name {
		case "false":
			return LLVMConstInt(LLVMInt1Type(), 0, 0)
		case "true":
			return LLVMConstInt(LLVMInt1Type(), 1, 0)
		default:
			// see if we are referencing a local variable
			if let mem = self.getLocal(ast.name) {
				return LLVMBuildLoad(self.builder, mem, "")
			}

			// otherwise it should a be (global) function
			// XXX: TODO: maybe assert that this returns non-nil
			return LLVMGetNamedFunction(self.module, ast.name)
		}
	}

	// helpers for codegenBinaryOp
	func codegenIntComparison(
		op: String,
		_ lhs: LLVMValueRef,
		_ rhs: LLVMValueRef
	) -> LLVMValueRef
	{
		let comparisons = [
			"<":  LLVMIntSLT,
			"<=": LLVMIntSLE,
			">":  LLVMIntSGT,
			">=": LLVMIntSGE,
			"==": LLVMIntEQ,
			"!=": LLVMIntNE
		]

		if let opcode = comparisons[op] {
			return LLVMBuildICmp(self.builder, opcode, lhs, rhs, "")
		}

		assert(false, "unimplemented operator: \(op)")
		return nil
	}

	func codegenFloatComparison(
		op: String,
		_ lhs: LLVMValueRef,
		_ rhs: LLVMValueRef
	) -> LLVMValueRef
	{
		let comparisons = [
			"<":  LLVMRealOLT,
			"<=": LLVMRealOLE,
			">":  LLVMRealOGT,
			">=": LLVMRealOGE,
			"==": LLVMRealOEQ,
			"!=": LLVMRealONE
		]

		if let opcode = comparisons[op] {
			return LLVMBuildFCmp(self.builder, opcode, lhs, rhs, "")
		}

		assert(false, "unimplemented operator: \(op)")
		return nil
	}

	typealias ArithInstBuilder = (
		LLVMBuilderRef,
		LLVMValueRef,
		LLVMValueRef,
		UnsafePointer<CChar>
	) -> LLVMValueRef

	func codegenArithmetic(
		builders: [String: ArithInstBuilder],
		_ op: String,
		_ lhs: LLVMValueRef,
		_ rhs: LLVMValueRef
	) -> LLVMValueRef
	{
		if let fn = builders[op] {
			return fn(self.builder, lhs, rhs, "")
		}

		assert(false, "unimplemented operator \(op)")
		return nil
	}

	func codegenShortCircuitLogicalOp(ast: BinaryOpAST) -> LLVMValueRef {
		// First, we generate code for the left-hand side...
		let lhsVal = self.codegenExpr(ast.lhs)
		assert(lhsVal != nil)

		// ...and only then do we get the current basic block. That's
		// because the LHS may emit additional basic blocks, and this
		// way we can make sure that we obtain the immediate predecessor
		// for use in the PHI node.
		let lhsBBLast  = LLVMGetInsertBlock(self.builder)
		let rhsBBFirst = LLVMAppendBasicBlock(self.functions.last!, "")
		let endBB      = LLVMAppendBasicBlock(self.functions.last!, "")

		// Generate the short-circuiting conditional jump:
		// * if LHS is false, then LHS && anything is also false
		// * if LHS is true,  then LHS || anything is also true
		switch ast.op {
		case "&&":
			LLVMBuildCondBr(self.builder, lhsVal, rhsBBFirst, endBB)
		case "||":
			LLVMBuildCondBr(self.builder, lhsVal, endBB, rhsBBFirst)
		default:
			assert(false, "unimplemented logical operator: \(ast.op)")
		}

		// Generate code for the RHS
		LLVMPositionBuilderAtEnd(self.builder, rhsBBFirst)
		let rhsVal = self.codegenExpr(ast.rhs)
		assert(rhsVal != nil)
		let rhsBBLast = LLVMGetInsertBlock(self.builder)
		LLVMBuildBr(self.builder, endBB)

		// Finally, construct the PHI node.
		var vals = [ lhsVal, rhsVal ]
		var blocks = [ lhsBBLast, rhsBBLast ]

		LLVMPositionBuilderAtEnd(self.builder, endBB)
		let phi = LLVMBuildPhi(self.builder, ast.typeAnn!.llvmType(), "")
		LLVMAddIncoming(phi, &vals, &blocks, CUnsignedInt(vals.count))

		return phi
	}

	func codegenAssignment(ast: BinaryOpAST) -> LLVMValueRef {
		let lhs = ast.lhs as! IdentifierAST
		let mem = self.getLocal(lhs.name)!
		let rhs = self.codegenExpr(ast.rhs)

		assert(rhs != nil)
		assert(ast.typeAnn! is VoidType)

		// XXX: what's the return value of the store instruction?
		return LLVMBuildStore(self.builder, rhs, mem)
		// return LLVMConstNull(ast.typeAnn!.llvmType())
	}

	func codegenBinaryOp(ast: BinaryOpAST) -> LLVMValueRef {
		let logicalOps = [ "&&", "||" ]
		let assignOps = [ "=" ]
		let arithOps = [ "+", "-", "*", "/" ]
		let cmpOps = [ "<", "<=", ">", ">=", "==", "!=" ]

		// Logical operators short-circuit so we treat them specially
		if logicalOps.contains(ast.op) {
			return self.codegenShortCircuitLogicalOp(ast)
		}

		// Assignment operators are also special because they don't
		// read their LHS, instead they write it.
		if assignOps.contains(ast.op) {
			return self.codegenAssignment(ast)
		}

		let lhs = self.codegenExpr(ast.lhs)
		assert(lhs != nil)

		let rhs = self.codegenExpr(ast.rhs)
		assert(rhs != nil)

		let intArithArr = [
			LLVMBuildAdd,
			LLVMBuildSub,
			LLVMBuildMul,
			LLVMBuildSDiv
		]

		let floatArithArr = [
			LLVMBuildFAdd,
			LLVMBuildFSub,
			LLVMBuildFMul,
			LLVMBuildFDiv
		]

		let intBuilders = Dictionary(keys: arithOps, values: intArithArr)
		let floatBuilders = Dictionary(keys: arithOps, values: floatArithArr)

		// Is it an arithmetic operator?
		// XXX: TODO: do something with the String overload of '+'
		if arithOps.contains(ast.op) {
			let builders = ast.typeAnn! is IntType ? intBuilders : floatBuilders
			return self.codegenArithmetic(builders, ast.op, lhs, rhs)
		}

		// Is it a comparison operator?
		if cmpOps.contains(ast.op) {
			let builder = ast.lhs.typeAnn! is IntType ? self.codegenIntComparison : self.codegenFloatComparison
			return builder(ast.op, lhs, rhs)
		}

		assert(false, "unimplemented operator \(ast.op)")
		return nil
	}

	func codegenPrefixOp(ast: PrefixOpAST) -> LLVMValueRef {
		let childVal = self.codegenExpr(ast.child)
		assert(childVal != nil)

		switch ast.op {
		case "+":
			return childVal
		case "-":
			if ast.child.typeAnn! is IntType {
				return LLVMBuildNeg(self.builder, childVal, "")
			} else {
				return LLVMBuildFNeg(self.builder, childVal, "")
			}
		case "!":
			assert(ast.child.typeAnn! is BoolType, "NOT of non-Boolean")
			return LLVMBuildNot(self.builder, childVal, "")
		default:
			self.errmsg = "unrecognized operator \(ast.op)"
			self.errnode = ast
			return nil
		}
	}

	func codegenFuncCall(ast: FuncCallAST) -> LLVMValueRef {
		let fnValue = self.codegenExpr(ast.function)
		assert(fnValue != nil)

		var args: [LLVMValueRef] = []

		// only attempt to generate argument if it's not void
		if let arg = ast.parameter {
			let argValue = self.codegenExpr(arg)
			assert(argValue != nil)
			args.append(argValue)
		}

		// TODO: temporaries created for arguments should be cleaned up
		return LLVMBuildCall(
			self.builder,
			fnValue,
			&args,
			CUnsignedInt(args.count),
			""
		)
	}

	//
	// Codegen functions for statements
	//
	func codegenFuncDecl(ast: FuncDeclAST) -> (LLVMValueRef, FunctionType) {
		let tp = ast.typeAnn as! FunctionType
		let fn = LLVMAddFunction(self.module, ast.name, tp.llvmType())
		// LLVMSetFunctionCallConv(fn, LLVMCCallConv.rawValue)
		return (fn, tp)
	}

	func codegenFuncDef(ast: FuncDefAST) {
		// Create function declaration and transform it into
		// a definition by adding an entry point basic block
		let (fn, tp) = self.codegenFuncDecl(ast)

		let bb = LLVMAppendBasicBlock(fn, "entry")
		LLVMPositionBuilderAtEnd(self.builder, bb)

		// Create outermost pseudo-scope for function argument
		self.scopes.append([:])

		// register ourselves as the innermost function being compiled
		self.functions.append(fn)

		// pop argument pseudo-scope and current function on exit
		defer {
        self.callDestructors(scopes.last!)
			  self.scopes.removeLast()
			  assert(self.scopes.count == 0, "stray scope on scope stack")
			  self.functions.removeLast()
		}

		// if we have an argument, 'declare' it.
		// This is done via an additional alloca and a store into memory,
		// because this way we can handle function arguments uniformly,
		// as if they were local variables (which they conceptually are)
		if let argName = ast.paramName {
			let ptr = LLVMBuildAlloca(
				self.builder,
				tp.argType.llvmType(),
				argName
			)
			// 0th argument
			LLVMBuildStore(self.builder, LLVMGetParam(fn, 0), ptr)
			// 0th (outermost) scope
			scopes[0][argName] = ptr
		}

		// codegen function body
		self.codegenStmt(ast.body)

		// If there's no return at the end of the function, then:
		// TODO: 'has the function returned a value if necessary?'
		// IS NOT equivalent to 'is the last statement a return?'!
		// Full control flow analysis is necessary for enumerating
		// and checking returns from all possible code paths.
		// For now, we just assume that:
		// 1. value-returning functions always return a value
		// 2. void-returning functions have no redundant 'return' @ the end
		// XXX: TODO: don't assume, perform proper CFA
		if tp.retType is VoidType {
			LLVMBuildRetVoid(self.builder)
		} else {
			LLVMBuildUnreachable(self.builder)
		}
	}

	func codegenBlock(ast: BlockAST) {
		  scopes.append([:])
		  defer {
          self.callDestructors(scopes.last!)
          scopes.removeLast()
      }

		  for child in ast.children {
			    self.codegenStmt(child)
		  }
	}

	func codegenReturn(ast: ReturnAST) {
		// XXX: TODO: generate code for cleaning up scopes:
		// call destructors, traversing scopes from inside out

		if let expr = ast.expression {
			let exprValue = self.codegenExpr(expr)
			assert(exprValue != nil)
			LLVMBuildRet(self.builder, exprValue)
		} else {
			LLVMBuildRetVoid(self.builder)
		}

		// we need a new BB since return is a terminating instruction
		let next = LLVMAppendBasicBlock(self.functions.last!, "next")
		LLVMPositionBuilderAtEnd(self.builder, next)
	}

	func codegenIfThenElse(ast: IfThenElseAST) {
		// codegen condition
		let condVal = self.codegenExpr(ast.condition)
		assert(condVal != nil)

		// codegen conditional branch
		let bbThen = LLVMAppendBasicBlock(self.functions.last!, "then")
		let bbElse = LLVMAppendBasicBlock(self.functions.last!, "else")
		let bbEndIf = LLVMAppendBasicBlock(self.functions.last!, "endif")
		LLVMBuildCondBr(self.builder, condVal, bbThen, bbElse)

		// codegen "then" branch
		LLVMPositionBuilderAtEnd(self.builder, bbThen)
		self.codegenStmt(ast.thenBranch)
		LLVMBuildBr(self.builder, bbEndIf)

		// codegen "else" branch
		LLVMPositionBuilderAtEnd(self.builder, bbElse)
		if let elseBranch = ast.elseBranch {
			self.codegenStmt(elseBranch)
		}
		LLVMBuildBr(self.builder, bbEndIf)

		// continue at merge point
		LLVMPositionBuilderAtEnd(self.builder, bbEndIf)
	}

	func codegenWhileLoop(ast: WhileLoopAST) {
		let bbCond = LLVMAppendBasicBlock(self.functions.last!, "cond")
		let bbBody = LLVMAppendBasicBlock(self.functions.last!, "body")
		let bbExit = LLVMAppendBasicBlock(self.functions.last!, "endwhile")

		// Generate condition in a fresh basic block,
		// as we will need to jump back to it.
		LLVMBuildBr(self.builder, bbCond)

		// Generate condition and conditional branch
		LLVMPositionBuilderAtEnd(self.builder, bbCond)
		let condVal = self.codegenExpr(ast.condition)
		assert(condVal != nil)

		LLVMBuildCondBr(self.builder, condVal, bbBody, bbExit)

		// Generate body
		LLVMPositionBuilderAtEnd(self.builder, bbBody)
		self.codegenStmt(ast.body)

		// Generate unconditional jump back to condition
		LLVMBuildBr(self.builder, bbCond)

		// Continue after merge point
		LLVMPositionBuilderAtEnd(self.builder, bbExit)
	}

	func codegenVarDecl(ast: VarDeclAST) {
		// This should call the constructor of a non-trivially
		// initialized type, so in theory we shouldn't need to
		// worry about that separately.
		// XXX: TODO: this will definitely change if we ever
		// make the initializer expression optional!
		let initVal = self.codegenExpr(ast.initExpr)
		assert(initVal != nil)

		// allocate storage
		let mem = LLVMBuildAlloca(
			self.builder,
			ast.typeAnn!.llvmType(),
			ast.name
		)

		// Store initializer value
		LLVMBuildStore(self.builder, initVal, mem)

		// add the allocated pointer to the symbol table
		self.scopes[self.scopes.count - 1][ast.name] = mem
	}

	//
	// Public API: the codegen function for the top-level program
	//
	// returns: pointer to module (TU) in the global LLVM context
	func codegenProgram(ast: ProgramAST, _ name: String) -> LLVMModuleRef {
		self.module = LLVMModuleCreateWithName(name)

		// Declare runtime/intrinsic/magic/built-in functions
		self.declareBuiltInFunctions(self.module)

		for child in ast.children {
			self.codegenStmt(child)
		}

		// Self-checking - just in case I screwed up codegen
		LLVMVerifyModule(self.module, LLVMAbortProcessAction, nil)
		return self.module
	}
}
