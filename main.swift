//
// main.swift
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


func removeExtension(var path: String) -> String {
	if let ext = NSURL(string: path)?.pathExtension {
		let range = path.rangeOfString(
			"." + ext, // path extension does _not_ include the dot
			options: .BackwardsSearch
		)
		path.removeRange(range!)
	}
	return path
}

func main() {
	let fname = String.fromCString(Process.unsafeArgv[1])!

	print("compiling \(fname)...")

	let source = try! NSString(contentsOfFile: fname, encoding: NSUTF8StringEncoding)

	print("lex...")
	let lexer = Lexer(source as String)

	guard let tokens = lexer.lex() else {
		print(lexer.error)
		print(lexer.location)
		return
	}

	print("parse...")
	let parser = Parser(tokens)
	guard var ast = parser.parse() else {
		print(parser.error)
		print(parser.location)
		return
	}

	print("typecheck...")
	var ctx = DeclCtx()
	guard let _ = ast.inferType(&ctx) else {
		print(ctx.errmsg!)
		print("at \(ctx.errnode!.loc)")
		return
	}

	print("constant propagation...")
	ast = performConstProp(ast) as! ProgramAST

	print("dead code elimination...")
	ast = performDCE(ast) as! ProgramAST

	// For debugging purposes...
	// print(ast.toString(0))

	// Generate LLVM bitcode
	print("codegen...")
	let codeGen = CodeGen()
	let module = codeGen.codegenProgram(ast, fname)
	if module != nil { // "if let" doesn't work with C pointers...
		let execName = removeExtension(fname)
		let bitcodeName = execName + ".bc"

		// write binary bitcode to file
		LLVMWriteBitcodeToFile(module, bitcodeName)
		// make it human-readable (for debugging)
		system("llvm-dis \(bitcodeName)")
		// Piggy-back on clang to invoke linker
		print("linking \(bitcodeName) -> \(execName)...")
		system("clang -std=c99 -Wall -O -o \(execName) \(bitcodeName) runtime.c")
	} else {
		print(codeGen.errmsg!)
		print("at \(codeGen.errnode!.loc)")
	}
}

main()
