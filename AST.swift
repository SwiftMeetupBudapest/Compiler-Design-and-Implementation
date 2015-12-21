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
    return (0..<n).map({ _ in "  " }).reduce("", combine: {$0 + $1})
}

class AST {
    let loc: SrcLoc
    var typeAnn: TypeAnn?

    init(_ loc: SrcLoc) {
        self.loc = loc
        self.typeAnn = nil
    }

    func toString(level: Int) -> String {
        return indent(level) + "<AST \(self); type = \(self.typeAnn)>\n"
    }

    func inferType(inout ctx: DeclCtx) -> TypeAnn {
        assert(false, "cannot infer type of generic AST")
        return VoidType()
    }
}

class ProgramAST : AST {
    let children: [AST]

    init(_ loc: SrcLoc, _ children: [AST]) {
        self.children = children
        super.init(loc)
    }

    override func toString(level: Int) -> String {
        var s = indent(level) + "Program\n"
        s += children.reduce("", combine: {$0 + $1.toString(level + 1).trimTail() + "\n"})
        return s
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        for child in children {
            child.inferType(&ctx)
        }
        return VoidType()
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
        s += " (inf. type = \(self.typeAnn))\n"
        return s
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        let ptype = TypeFromTypeName(paramType)
        let rtype = TypeFromTypeName(returnType)
        self.typeAnn = FunctionType(ptype, rtype)
        ctx.globals[self.name] = self.typeAnn
        return self.typeAnn!
    }
}

class FuncDefAST : FuncDeclAST {
    let body: AST

    init(
         _ loc: SrcLoc,
         _ name: String,
         _ paramName: String?,
         _ paramType: String?,
         _ returnType: String?,
         _ body: AST
    ) {
        self.body = body
        super.init(loc, name, paramName, paramType, returnType)
    }

    override func toString(level: Int) -> String {
        var s = super.toString(level).trimTail() + "\n"
        s += body.toString(level + 1).trimTail() + "\n"
        return s
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        // If we have a parameter, we add its declaration.
        if let pname = self.paramName, ptype = self.paramType {
            ctx.scopes.append([pname:TypeFromTypeName(ptype)])
        }

        let ownType = super.inferType(&ctx)
        self.body.inferType(&ctx)
        return ownType
    }
}

class BlockAST : AST {
    let children: [AST]

    init(_ loc: SrcLoc, _ children: [AST]) {
        self.children = children
        super.init(loc)
    }

    override func toString(level: Int) -> String {
        var s = indent(level)
        s += "Block\n"
        s += children.reduce("", combine: {$0 + $1.toString(level + 1).trimTail() + "\n"})
        return s
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        // push scope
        ctx.scopes.append([:])

        for child in children {
            child.inferType(&ctx)
        }

        // pop scope
        ctx.scopes.removeLast()
        
        self.typeAnn = VoidType()
        return self.typeAnn!
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

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        if let expr = self.expression {
            self.typeAnn = expr.inferType(&ctx)
        } else {
            self.typeAnn = VoidType()
        }
        return self.typeAnn!
    }
}

class IfThenElseAST : AST {
    let condition: AST
    let thenBranch: AST
    let elseBranch: AST?

    init(_ loc: SrcLoc, _ condition: AST, _ thenBranch: AST, _ elseBranch: AST?) {
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

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        self.condition.inferType(&ctx)
        self.thenBranch.inferType(&ctx)
        self.elseBranch?.inferType(&ctx)
        
        self.typeAnn = VoidType()
        return self.typeAnn!
    }
}

class WhileLoopAST : AST {
    let condition: AST
    let body: AST

    init(_ loc: SrcLoc, _ condition: AST, _ body: AST) {
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
    
    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        self.condition.inferType(&ctx)
        self.body.inferType(&ctx)

        self.typeAnn = VoidType()
        return self.typeAnn!
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

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        self.typeAnn = self.initExpr.inferType(&ctx)
        // Array.last is read-only...
        ctx.scopes[ctx.scopes.count - 1][self.name] = self.typeAnn!
        return self.typeAnn!
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
        return indent(level) + "Integer \(value) (type = \(self.typeAnn))\n"
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        self.typeAnn = IntType()
        return self.typeAnn!
    }
}
    
class FloatingLiteralAST : AST {
    let value: Double

    init(_ loc: SrcLoc, _ value: Double) {
        self.value = value
        super.init(loc)
    }

    override func toString(level: Int) -> String {
        return indent(level) + "Floating \(value) (type = \(self.typeAnn))\n"
    }
    
    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        self.typeAnn = DoubleType()
        return self.typeAnn!
    }
}

class StringLiteralAST : AST {
    let value: String
    
    init(_ loc: SrcLoc, _ value: String) {
        self.value = value
        super.init(loc)
    }

    override func toString(level: Int) -> String {
        return indent(level) + "String \"\(value)\" (type = \(self.typeAnn))\n"
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        self.typeAnn = StringType()
        return self.typeAnn!
    }
}
              
class IdentifierAST : AST {
    let name: String
    
    init(_ loc: SrcLoc, _ name: String) {
        self.name = name
        super.init(loc)
    }

    override func toString(level: Int) -> String {
        return indent(level) + "Identifier \(name) (type = \(self.typeAnn))\n"
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
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

        assert(false, "undeclared identifier: \(self.name)")
        return self.typeAnn! // nil at this point, would crash anyway
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
        var s = indent(level) + "BinaryOp \"\(op)\" (type = \(self.typeAnn))\n"
        s += lhs.toString(level + 1).trimTail() + "\n"
        s += rhs.toString(level + 1).trimTail() + "\n"
        return s
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        let lt = lhs.inferType(&ctx)
        let rt = rhs.inferType(&ctx)

        if lt is IntType && rt is IntType {
            self.typeAnn = IntType()
        } else if lt is IntType && rt is DoubleType
                  || lt is DoubleType && rt is IntType {
            self.typeAnn = DoubleType()
        } else if lt is DoubleType && rt is DoubleType {
            self.typeAnn = DoubleType()
        } else if op == "+" && lt is StringType && rt is StringType {
            self.typeAnn = StringType()
        } else {
            assert(
                false,
                "operator \(op) cannot have operands of type \(lt) and \(lt)"
            )
        }
        
        return self.typeAnn!
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
        var s = indent(level) + "Prefix \(op) (type = \(self.typeAnn))\n"
        s += child.toString(level + 1).trimTail() + "\n"
        return s
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        let ct = child.inferType(&ctx)
        if ct is IntType || ct is DoubleType {
            self.typeAnn = ct
        } else {
            assert(
                false,
                "prefix operator \(op) cannot have argument of type \(ct)"
            )
        }

        return self.typeAnn!
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

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        assert(false, "unimplemented")
        return self.typeAnn!
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
        var s = indent(level) + "Funcion Call (type = \(self.typeAnn))\n"
        s += indent(level + 1) + "Function:\n"
        s += function.toString(level + 2).trimTail() + "\n"
        
        if parameter != nil {
            s += indent(level + 1) + "Parameter:\n"
            s += parameter!.toString(level + 2).trimTail() + "\n"
        }
        
        return s
    }

    override func inferType(inout ctx: DeclCtx) -> TypeAnn {
        let actParamType: TypeAnn
        if let param = self.parameter {
            actParamType = param.inferType(&ctx)
        } else {
            actParamType = VoidType()
        }

        if let fnType = function.inferType(&ctx) as? FunctionType {
            let formalTypeName = String(UTF8String: object_getClassName(fnType.argType))
            let actualTypeName = String(UTF8String: object_getClassName(actParamType))
            if formalTypeName == actualTypeName {
                self.typeAnn = fnType.retType
            } else {
                // print(
                assert(
                    false,
                    "warning: function taking argument of type \(fnType.argType)" +
                    " was passed an argument of type \(actParamType)" +
                    " at \(self.loc)"    
                )
                // self.typeAnn = fnType.retType
            }
        } else {
            assert(
                false,
                "callee is of non-function type \(function.inferType(&ctx))"
            )
        }

        return self.typeAnn!
    }
}
