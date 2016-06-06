//
// TypeAnn.swift
//
// SwiSwi - a tiny Swift-like language
//
// Created for the Budapest Swift Meetup
// by Árpád Goretity (H2CO3)
// on 15/12/2015
//
// There's no warranty whatsoever.
//

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

	// For code generation.
	// Returns the LLVM representation of the type.
	func llvmType() -> LLVMTypeRef {
		assert(false, "cannot represent generic TypeAnn in LLVM")
		return nil
	}
}

final class VoidType : TypeAnn {
	override func toString() -> String {
		return "Void"
	}

	override func equals(rhs: TypeAnn) -> Bool {
		return rhs is VoidType // assumes final
	}

	override func llvmType() -> LLVMTypeRef {
		return LLVMVoidType()
	}
}

final class BoolType : TypeAnn {
	override func toString() -> String {
		return "Bool"
	}

	override func equals(rhs: TypeAnn) -> Bool {
		return rhs is BoolType // assumes final
	}

	override func llvmType() -> LLVMTypeRef {
		return LLVMInt1Type()
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

	override func llvmType() -> LLVMTypeRef {
		return LLVMInt64Type()
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

	override func llvmType() -> LLVMTypeRef {
		return LLVMDoubleType()
	}
}

final class StringType : TypeAnn {
    static var storedLlvmType: LLVMTypeRef? = nil
    
	  override func toString() -> String {
		    return "String";
	  }
    
	  override func equals(rhs: TypeAnn) -> Bool {
		    return rhs is StringType // assumes final
	  }

	  // Strings are represented by:
	  // struct string {
	  //	 char *begin;
	  //	 uint64_t length;
	  // }
	  override func llvmType() -> LLVMTypeRef {
        if let storedLlvmType = StringType.storedLlvmType {
            return storedLlvmType
        }
        
		    var elems = [
			      LLVMPointerType(LLVMInt8Type(), 0), // char * in addr. space #0
			      LLVMInt64Type()
		    ]
        
		    // 0: not packed
		    StringType.storedLlvmType = LLVMStructType(&elems, UInt32(elems.count), 0)
        print("Generating String type \(StringType.storedLlvmType!)")
        return StringType.storedLlvmType!
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

	override func llvmType() -> LLVMTypeRef {
		// a function with a 'Void' argument is a
		// special case: it means '0 arguments'.
		var args: [LLVMTypeRef] = []
		if self.argType != VoidType() {
			args.append(self.argType.llvmType())
		}

		return LLVMFunctionType(
			self.retType.llvmType(),
			&args,
			UInt32(args.count),
			0 // 0: not variadic
		)
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
