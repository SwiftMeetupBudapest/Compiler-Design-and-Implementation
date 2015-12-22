class TypeAnn {
	init() {}

	func toString() -> String {
		return "Type"
	}

	func equals(rhs: TypeAnn) -> Bool {
		return false
	}

	func isNumeric() -> Bool {
		return false
	}
}

final class VoidType : TypeAnn {
	override func toString() -> String {
		return "Void"
	}

	override func equals(rhs: TypeAnn) -> Bool {
		return rhs is VoidType // assumes final
	}
}

final class BoolType : TypeAnn {
	override func toString() -> String {
		return "Bool"
	}

	override func equals(rhs: TypeAnn) -> Bool {
		return rhs is BoolType // assumes final
	}
}

final class IntType : TypeAnn {
	override func toString() -> String {
		return "Int";
	}

	override func equals(rhs: TypeAnn) -> Bool {
		return rhs is IntType // assumes final
	}

	override func isNumeric() -> Bool {
		return true
	}
}

final class DoubleType : TypeAnn {
	override func toString() -> String {
		return "Double";
	}

	override func equals(rhs: TypeAnn) -> Bool {
		return rhs is DoubleType // assumes final
	}

	override func isNumeric() -> Bool {
		return true
	}
}

final class StringType : TypeAnn {
	override func toString() -> String {
		return "String";
	}

	override func equals(rhs: TypeAnn) -> Bool {
		return rhs is StringType // assumes final
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
		// TODO: may need parentheses in the future (precedence!)
		return "\(self.argType.toString()) -> \(self.retType.toString())";
	}

	override func equals(rhs: TypeAnn) -> Bool {
		guard let rt = rhs as? FunctionType else {
			return false
		}

		return argType.equals(rt.argType) && retType.equals(rt.retType)
	}
}

// Convenience equality operators
func ==(lhs: TypeAnn, rhs: TypeAnn) -> Bool {
	return lhs.equals(rhs)
}

func !=(lhs: TypeAnn, rhs: TypeAnn) -> Bool {
	return !(lhs == rhs)
}

func TypeFromTypeName(oname: String?) -> TypeAnn {
	guard let name = oname else {
		return VoidType()
	}

	switch name {
	case "Void":   return VoidType()
	case "Bool":   return BoolType()
	case "Int":    return IntType()
	case "Double": return DoubleType()
	case "String": return StringType()
	default:
		assert(false, "unknown type name: \(name)")
		return VoidType()
	}
}
