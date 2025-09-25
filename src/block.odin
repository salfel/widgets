package main

import "core:fmt"

block_make :: proc(
	classes: []string,
	allocator := context.allocator,
) -> (
	widget: ^Widget,
	ok: bool = true,
) #optional_ok {
	widget = box_make(classes, allocator) or_return
	widget.type = .Block
	widget.layout.type = .Block

	return
}
