class TypeAnn {
    init() {}

    func toString() -> String {
        return "Type"
    }
}

class VoidType : TypeAnn {
    override func toString() -> String {
        return "()"
    }    
}

class IntType : TypeAnn {
    override func toString() -> String {
        return "Int";
    }
}

class DoubleType : TypeAnn {
    override func toString() -> String {
        return "Double";
    }
}

class StringType : TypeAnn {
    override func toString() -> String {
        return "String";
    }
}

class FunctionType : TypeAnn {
    let argType: TypeAnn
    let retType: TypeAnn

    init(_ argType: TypeAnn, _ retType: TypeAnn) {
        self.argType = argType
        self.retType = retType
        super.init()
    }

    override func toString() -> String {
        return "\(self.argType.toString()) -> \(self.retType.toString())";
    }
}

func TypeFromTypeName(oname: String?) -> TypeAnn {
    guard let name = oname else {
        return VoidType()
    }
    switch name {
    case "()":     return VoidType()
    case "Void":   return VoidType()
    case "Int":    return IntType()
    case "Double": return DoubleType()
    case "String": return StringType()
    default:
        assert(false, "unknown type name \(name)")
        return VoidType()
    }
}
