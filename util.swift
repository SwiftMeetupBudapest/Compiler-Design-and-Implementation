//
// util.swift
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

extension String {
	func trimTail() -> String {
		if self.characters.count > 0 && self[self.endIndex.predecessor()] == "\n" {
			return self.substringToIndex(self.endIndex.predecessor())
		}
		return self
	}
}

extension Dictionary {
	init(keys: [Key], values: [Value]) {
		self.init()
		assert(keys.count == values.count, "there must be exactly as many keys as values")
		for i in 0..<keys.count {
			self[keys[i]] = values[i]
		}
	}
}
