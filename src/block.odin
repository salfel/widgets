package main

import "core:fmt"

block_make :: proc(allocator := context.allocator) -> (box: ^Box, ok: bool = true) #optional_ok {
	box = box_make(allocator) or_return
	box.type = .Block
	box.layout.type = .Block

	return
}
