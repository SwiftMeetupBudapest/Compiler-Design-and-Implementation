all:
	xcrun -sdk macosx swiftc Lexer.swift AST.swift Parser.swift TypeAnn.swift DeclCtx.swift util.swift main.swift -o swiswi
