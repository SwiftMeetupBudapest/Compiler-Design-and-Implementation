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

func main() {
	let fname = String.fromCString(Process.unsafeArgv[1])!
	let source = try! NSString(contentsOfFile: fname, encoding: NSUTF8StringEncoding)

	let lexer = Lexer(source as String)

	guard let tokens = lexer.lex() else {
		print(lexer.error)
		print(lexer.location)
		return
	}

	let parser = Parser(tokens)
	guard let ast = parser.parse() else {
		print(parser.error)
		print(parser.location)
		return
	}

	var ctx = DeclCtx()
	if ast.inferType(&ctx) != nil {
		print(ast.toString(0))
	} else {
		print(ctx.errmsg!)
		print("at \(ctx.errnode!.loc)")
	}
}

main()
