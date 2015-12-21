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

let fname = String.fromCString(Process.unsafeArgv[1])!
let source = try NSString(contentsOfFile: fname, encoding: NSUTF8StringEncoding)
let lexer = Lexer(source as String)


if let tokens = lexer.lex() {
	let parser = Parser(tokens)
	if let ast = parser.parse() {
        var ctx = DeclCtx()
        ast.inferType(&ctx)
		print(ast.toString(0))
	} else {
		print(parser.error)
		print(parser.location)
	}
} else {
	print(lexer.error)
	print(lexer.location)
}
