package main

import "core:fmt"

block_make :: proc(allocator := context.allocator) -> (widget: Widget, ok: bool = true) #optional_ok {
	widget = box_make(allocator) or_return
	widget.type = .Block
	widget.layout.type = .Block

	return
}
