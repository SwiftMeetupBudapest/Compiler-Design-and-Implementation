all:
	xcrun -sdk macosx swiftc \
	Lexer.swift \
	AST.swift \
	Parser.swift \
	TypeAnn.swift \
	DeclCtx.swift \
	CodeGen.swift \
	util.swift \
	main.swift \
	-o swiswi \
	-g \
	-O \
	-I /usr/local/include/ \
	-L /usr/local/lib \
	-Xcc -D__STDC_CONSTANT_MACROS \
	-Xcc -D__STDC_LIMIT_MACROS \
	-Xcc -D__STDC_FORMAT_MACROS \
	-import-objc-header LLVM-bridge.h \
	$(shell llvm-config --libs)	 \
	-lc++ \
	-lncurses

clean:
	rm swiswi *.bc *.ll
