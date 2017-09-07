Compiler Design and Implementation
==========

This repository contains the code accompanying the practice-oriented
parts of the "Compiler Design and Implementation" series of lectures
performed during the 2015/16 season of Budapest Swift Meetup.

The code usually closely resembles what has been written during
the live coding sessions. Bug fixes, other improvements and
modifications may be committed without notice, though.

The code is placed into the public domain; there is no warranty
whatsoever.

Archive
==========
(Slides, videos and code of previous meetups)
--------

Presentation slides in PDF and Keynote format are all available in the [`Slides`](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/tree/master/Slides) directory.

The code has evolved continuously, during each meetup. It now contains a lexer, a parser, an AST definition, a primitive AST-based "optimizer", an LLVM code generator, and a minimal runtime library for SwiSwi, our toy language being compiled.

* Part 1: Introduction; Lexical Analysis
	* [Slides](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/Slides/Swift_Compiler_Design_1.pdf)
	* [Code](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/Lexer.swift)
	* [Video (in Hungarian)](https://www.youtube.com/watch?v=XIpuHfgIey4)

* Part 2: Parsing (Syntactic Analysis)
	* [Slides](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/Slides/Swift_Compiler_Design_2.pdf)
	* [Code for the parser](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/Parser.swift)
	* [Code for the AST definition](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/AST.swift)

* Part 3: Semantic Analysis (in: Type Checking and Inference)
	* [Slides](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/Slides/Swift_Compiler_Design_3_final.pdf)
	* [Code for type annotations](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/TypeAnn.swift)
	* (The AST already contains type inference code)
	* [Video (in Hungarian)](https://www.youtube.com/watch?v=1si_CDdebpc)

* Part 4: Low-level Code Generation - lowering to LLVM IR
	* [Slides](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/Slides/Swift_Meetup_Compiler_pt4_CodeGen.pdf)
	* [Code](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/CodeGen.swift)
	* [Presentation Screencast (Hungarian)](https://www.youtube.com/watch?v=wVN_0WDsBAk)
	* [Live Coding Screencast (Hungarian and English)](https://www.youtube.com/watch?v=vejnICDjQks)

* Part 5: Optimization
	* [Slides](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/Slides/Swift_Compiler_Design_5.pdf)
	* [Code for a primitive, AST-based const propagation and folding pass](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/ConstProp.swift)

* Part 6: Debugging and Runtime
	* [Slides](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/Slides/Swift_Meetup_Compiler_Design_and_Implementation_pt6.key)
	* [Code for the runtime library, containing e.g. String ctors and dtors](https://github.com/SwiftMeetupBudapest/Compiler-Design-and-Implementation/blob/master/runtime.c)
