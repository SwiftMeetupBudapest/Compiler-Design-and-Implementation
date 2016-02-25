//
// AST.swift
//
// SwiSwi - a tiny Swift-like language
//
// Created for the Budapest Swift Meetup
// by Árpád Goretity (H2CO3)
// on 28/10/2015
//
// There's no warranty whatsoever.
//

import Foundation

func indent(n: Int) -> String {
	return (0..<n).map({ _ in "  " }).reduce("", combine: { $0 + $1 })
}

class AST {
	let loc: SrcLoc
	var typeAnn: TypeAnn?

	init(_ loc: SrcLoc) {
		self.loc = loc
		self.typeAnn = nil
	}

	func toString(level: Int) -> String {
		return indent(level) + "<AST \(self); type = \(self.typeAnn?.toString())>\n"
	}

	func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		assert(false, "cannot infer type of abstract AST node")
		return nil
	}
}

class ProgramAST : AST {
	var children: [AST]

	init(_ loc: SrcLoc, _ children: [AST]) {
		self.children = children
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "Program\n"
		s += children.reduce("", combine: { $0 + $1.toString(level + 1).trimTail() + "\n" })
		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		for child in children {
			if child.inferType(&ctx) == nil {
				return nil
			}
		}

		self.typeAnn = VoidType()
		return self.typeAnn
	}
}

class EmptyStmtAST : AST {
	override init(_ loc: SrcLoc) {
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		return indent(level) + "Empty\n"
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		self.typeAnn = VoidType()
		return self.typeAnn
	}
}

class FuncDeclAST : AST {
	let name: String
	let paramName: String?
	let paramType: String?
	let returnType: String?

	init(
		 _ loc: SrcLoc,
		 _ name: String,
		 _ paramName: String?,
		 _ paramType: String?,
		 _ returnType: String?
	) {
		self.name = name
		self.paramName = paramName
		self.paramType = paramType
		self.returnType = returnType
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "Function '\(name)'"
		if (paramName != nil) {
			s += " :: \(paramName!): \(paramType!)"
		}
		if (returnType != nil) {
			s += paramName != nil ? " -> " : " :: "
			s += returnType!
		}
		s += " (inf. type = \(self.typeAnn?.toString()))\n"
		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		if ctx.globals[self.name] != nil {
			ctx.errmsg = "redeclaration of function \(self.name)"
			ctx.errnode = self
			return nil
		}

		let ptype = TypeFromTypeName(paramType)
		let rtype = TypeFromTypeName(returnType)
		self.typeAnn = FunctionType(ptype, rtype)
		ctx.globals[self.name] = self.typeAnn
		return self.typeAnn
	}
}

class FuncDefAST : FuncDeclAST {
	var body: BlockAST

	init(
		 _ loc: SrcLoc,
		 _ name: String,
		 _ paramName: String?,
		 _ paramType: String?,
		 _ returnType: String?,
		 _ body: BlockAST
	) {
		self.body = body
		super.init(loc, name, paramName, paramType, returnType)
	}

	override func toString(level: Int) -> String {
		var s = super.toString(level).trimTail() + "\n"
		s += body.toString(level + 1).trimTail() + "\n"
		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		// push outermost pseudo-scope for parameters
		ctx.scopes.append([:])

		// pop parameter pseudo-scope on exit
		defer {
			ctx.scopes.removeLast()
			assert(ctx.scopes.count == 0, "stray scope on scope stack")
		}

		// If we have a parameter, we add its declaration.
		if let pname = self.paramName, ptype = self.paramType {
			ctx.scopes[0][pname] = TypeFromTypeName(ptype)
		}

		guard let ownType = super.inferType(&ctx) as? FunctionType else {
			return nil
		}

		ctx.functionRetType = ownType.retType
		defer { ctx.functionRetType = nil }

		return self.body.inferType(&ctx) != nil ? ownType : nil
	}
}

class BlockAST : AST {
	var children: [AST]

	init(_ loc: SrcLoc, _ children: [AST]) {
		self.children = children
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level)
		s += "Block\n"
		s += children.reduce("", combine: { $0 + $1.toString(level + 1).trimTail() + "\n" })
		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		// push scope
		ctx.scopes.append([:])
		// pop scope on exit
		defer { ctx.scopes.removeLast() }

		for child in children {
			if child.inferType(&ctx) == nil {
				return nil
			}
		}

		self.typeAnn = VoidType()
		return self.typeAnn
	}
}

class ReturnAST : AST {
	let expression: AST?

	override init(_ loc: SrcLoc) {
		expression = nil
		super.init(loc)
	}

	init(_ loc: SrcLoc, _ expression: AST) {
		self.expression = expression
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "Return\n"
		if let expr = expression {
			s += expr.toString(level + 1).trimTail() + "\n"
		}
		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		if let expr = self.expression {
			guard let type = expr.inferType(&ctx) else {
				return nil
			}
			self.typeAnn = type
		} else {
			self.typeAnn = VoidType()
		}

		if self.typeAnn! != ctx.functionRetType! {
			ctx.errmsg = "Cannot return value of type \(self.typeAnn!.toString()) from function returning \(ctx.functionRetType!.toString())"
			ctx.errnode = self.expression ?? self
			return nil
		}

		return self.typeAnn
	}
}

class IfThenElseAST : AST {
	let condition: AST
	var thenBranch: BlockAST
	var elseBranch: AST?

	init(_ loc: SrcLoc, _ condition: AST, _ thenBranch: BlockAST, _ elseBranch: AST?) {
		self.condition = condition
		self.thenBranch = thenBranch
		self.elseBranch = elseBranch
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "If\n"
		s += indent(level + 1) + "Condition:\n"
		s += condition.toString(level + 2).trimTail() + "\n"
		s += indent(level + 1) + "Then:\n"
		s += thenBranch.toString(level + 2).trimTail() + "\n"

		if elseBranch != nil {
			s += indent(level + 1) + "Else:\n"
			s += elseBranch!.toString(level + 2).trimTail() + "\n"
		}

		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		guard let condType = self.condition.inferType(&ctx) else {
			return nil
		}

		if condType != BoolType() {
			ctx.errmsg = "condition of if statement must be a Boolean"
			ctx.errnode = self.condition
			return nil
		}

		if self.thenBranch.inferType(&ctx) == nil {
			return nil
		}

		if let eb = self.elseBranch {
			if eb.inferType(&ctx) == nil {
				return nil
			}
		}

		self.typeAnn = VoidType()
		return self.typeAnn
	}
}

class WhileLoopAST : AST {
	let condition: AST
	var body: BlockAST

	init(_ loc: SrcLoc, _ condition: AST, _ body: BlockAST) {
		self.condition = condition
		self.body = body
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "While Loop\n"
		s += indent(level + 1) + "Condition:\n"
		s += condition.toString(level + 2).trimTail() + "\n"
		s += indent(level + 1) + "Body:\n"
		s += body.toString(level + 2).trimTail() + "\n"
		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		guard let condType = self.condition.inferType(&ctx) else {
			return nil
		}

		if condType != BoolType() {
			ctx.errmsg = "condition of while loop must be a Boolean"
			ctx.errnode = self.condition
			return nil
		}

		if self.body.inferType(&ctx) == nil {
			return nil
		}

		self.typeAnn = VoidType()
		return self.typeAnn
	}
}

class VarDeclAST : AST {
	let name: String
	let initExpr: AST

	init(_ loc: SrcLoc, _ name: String, _ initExpr: AST) {
		self.name = name
		self.initExpr = initExpr
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "Variable Declaration\n"
		s += indent(level + 1) + "Name: \(name)\n"
		s += indent(level + 1) + "Init Expr:\n"
		s += initExpr.toString(level + 2).trimTail() + "\n"
		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		let nm = self.name

		// check for erroneous re-declaration and/or shadowing
		if ctx.scopes.map({ $0.contains({ $0.0 == nm }) }).contains(true) {
			ctx.errmsg = "re-declaration of variable: \(nm)"
			ctx.errnode = self
			return nil
		}

		guard let t = self.initExpr.inferType(&ctx) else {
			return nil
		}

		if t is VoidType {
			ctx.errmsg = "cannot create variable of void type"
			ctx.errnode = self.initExpr
			return nil
		}

		// Array.last is read-only...
		self.typeAnn = t
		ctx.scopes[ctx.scopes.count - 1][nm] = t
		return t
	}
}

///////////////////////////////
///////// Expressions /////////
///////////////////////////////

class IntegerLiteralAST : AST {
	let value: Int

	init(_ loc: SrcLoc, _ value: Int) {
		self.value = value
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		return indent(level) + "Integer \(value) (type = \(self.typeAnn?.toString()))\n"
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		self.typeAnn = IntType()
		return self.typeAnn
	}
}

class FloatingLiteralAST : AST {
	let value: Double

	init(_ loc: SrcLoc, _ value: Double) {
		self.value = value
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		return indent(level) + "Floating \(value) (type = \(self.typeAnn?.toString()))\n"
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		self.typeAnn = DoubleType()
		return self.typeAnn
	}
}

class StringLiteralAST : AST {
	let value: String

	init(_ loc: SrcLoc, _ value: String) {
		self.value = value
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		return indent(level) + "String \"\(value)\" (type = \(self.typeAnn?.toString()))\n"
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		self.typeAnn = StringType()
		return self.typeAnn
	}
}

class IdentifierAST : AST {
	let name: String

	init(_ loc: SrcLoc, _ name: String) {
		self.name = name
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		return indent(level) + "Identifier \(name) (type = \(self.typeAnn?.toString()))\n"
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		for scope in ctx.scopes.reverse() {
			if let type = scope[self.name] {
				self.typeAnn = type
				return type
			}
		}

		if let type = ctx.globals[self.name] {
			self.typeAnn = type
			return type
		}

		ctx.errmsg = "undeclared identifier: \(self.name)"
		ctx.errnode = self
		return nil
	}
}

class BinaryOpAST : AST {
	let op: String
	let lhs: AST
	let rhs: AST

	init(_ loc: SrcLoc, _ op: String, _ lhs: AST, _ rhs: AST) {
		self.op = op
		self.lhs = lhs
		self.rhs = rhs
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "BinaryOp \"\(op)\" (type = \(self.typeAnn?.toString()))\n"
		s += lhs.toString(level + 1).trimTail() + "\n"
		s += rhs.toString(level + 1).trimTail() + "\n"
		return s
	}

	// TODO: this needs a massive amount of refactoring
	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		guard let lt = lhs.inferType(&ctx), rt = rhs.inferType(&ctx) else {
			return nil
		}

		switch op {
		case "=":
			guard let ident = lhs as? IdentifierAST else {
				ctx.errmsg = "LHS of assignment must be a variable"
				ctx.errnode = self
				return nil
			}

			if ctx.globals[ident.name] != nil {
				ctx.errmsg = "Global \(ident.name) cannot be assigned to"
				ctx.errnode = ident
				return nil
			}

			if lt == rt {
				self.typeAnn = VoidType()
			} else {
				ctx.errmsg = "value of type \(rt.toString()) cannot be assigned to variable of type \(lt.toString())"
				ctx.errnode = self
				return nil
			}
		case "==", "!=", "<=", "<", ">=", ">":
			if lt is FunctionType || rt is FunctionType {
				ctx.errmsg = "function types cannot be compared using \(op)"
				ctx.errnode = self
				return nil
			}

			if lt == rt {
				self.typeAnn = BoolType()
			} else {
				ctx.errmsg = "values of type \(lt.toString()) and \(rt.toString()) cannot be compared using \(op)"
				ctx.errnode = self
				return nil
			}
		case "+":
			if lt == StringType() && rt == StringType() {
				self.typeAnn = StringType()
				break
			}
			fallthrough
		case "-", "*", "/":
			if lt is IntType && rt is IntType {
				self.typeAnn = IntType()
			} else if lt is DoubleType && rt is DoubleType {
				self.typeAnn = DoubleType()
			} else {
				ctx.errmsg = "\(op) cannot be applied to values of type \(lt.toString()) and \(rt.toString())"
				ctx.errnode = self
				return nil
			}
		case "&&", "||":
			if lt == BoolType() && rt == BoolType() {
				self.typeAnn = BoolType()
			} else {
				ctx.errmsg = "\(op) can only be applied to Bool arguments"
				ctx.errnode = self
				return nil
			}
		default:
			ctx.errmsg = "unknown operator: \(op)"
			ctx.errnode = self
			return nil
		}

		return self.typeAnn
	}
}

class PrefixOpAST : AST {
	let op: String
	let child: AST

	init(_ loc: SrcLoc, _ op: String, _ child: AST) {
		self.op = op
		self.child = child
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "Prefix \(op) (type = \(self.typeAnn?.toString()))\n"
		s += child.toString(level + 1).trimTail() + "\n"
		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		guard let ct = child.inferType(&ctx) else {
			return nil
		}

		switch op {
		case "!":
			if ct is BoolType {
				self.typeAnn = BoolType()
			} else {
				ctx.errmsg = "argument of unary '!' is not a Bool" +
				  " but a(n) \(ct.toString())"
				ctx.errnode = self
				return nil
			}
		case "+": fallthrough
		case "-":
			if ct.isNumeric() {
				self.typeAnn = ct
			} else {
				ctx.errmsg = "prefix operator \(op) cannot have an argument of type \(ct.toString())"
				ctx.errnode = self
				return nil
			}
		default:
			ctx.errmsg = "unrecognized operator \(op)"
			ctx.errnode = self
			return nil
		}

		return self.typeAnn
	}
}

class SubscriptAST : AST {
	let object: AST
	let subscriptExpr: AST

	init(_ loc: SrcLoc, _ object: AST, _ subscriptExpr: AST) {
		self.object = object
		self.subscriptExpr = subscriptExpr
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "Subscript\n"
		s += indent(level + 1) + "Object:\n"
		s += object.toString(level + 2).trimTail() + "\n"
		s += indent(level + 1) + "Subscript:\n"
		s += subscriptExpr.toString(level + 2).trimTail() + "\n"
		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		ctx.errmsg = "subscripts are unimplemented"
		ctx.errnode = self
		return nil
	}
}

class FuncCallAST : AST {
	let function: AST
	let parameter: AST?

	init(_ loc: SrcLoc, _ function: AST) {
		self.function = function
		self.parameter = nil
		super.init(loc)
	}

	init(_ loc: SrcLoc, _ function: AST, _ parameter: AST) {
		self.function = function
		self.parameter = parameter
		super.init(loc)
	}

	override func toString(level: Int) -> String {
		var s = indent(level) + "Funcion Call (type = \(self.typeAnn?.toString()))\n"
		s += indent(level + 1) + "Function:\n"
		s += function.toString(level + 2).trimTail() + "\n"

		if parameter != nil {
			s += indent(level + 1) + "Parameter:\n"
			s += parameter!.toString(level + 2).trimTail() + "\n"
		}

		return s
	}

	override func inferType(inout ctx: DeclCtx) -> TypeAnn? {
		let actParamType: TypeAnn
		if let param = self.parameter {
			if let pt = param.inferType(&ctx) {
				actParamType = pt
			} else {
				return nil
			}
		} else {
			actParamType = VoidType()
		}

		guard let maybeFnType = function.inferType(&ctx) else {
			return nil
		}

		guard let fnType = maybeFnType as? FunctionType else {
			ctx.errmsg = "callee is of non-function type \(maybeFnType.toString())"
			ctx.errnode = function
			return nil
		}

		if fnType.argType == actParamType {
			self.typeAnn = fnType.retType
		} else {
			ctx.errmsg = "function taking argument of type \(fnType.argType.toString())" +
			  " was passed an argument of type \(actParamType.toString())"
			ctx.errnode = self
			return nil
		}

		return self.typeAnn
	}
}
