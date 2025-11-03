package main

import "core:fmt"

button_make :: proc(allocator := context.allocator) -> (widget: ^Widget, ok := true) #optional_ok {
	widget = box_make(allocator) or_return
	widget.type = .Button

	return
}

button_set_onclick :: proc(widget: ^Widget, onclick: On_Click, user_ptr: rawptr) {
	assert(widget.type == .Button, fmt.tprint("expected Button, got:", widget.type))

	widget.on_click = {
		handler = onclick,
		data    = user_ptr,
	}
}
