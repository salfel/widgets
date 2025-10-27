package main

viewport_make :: proc(allocator := context.allocator) -> (widget: Widget, ok: bool) #optional_ok {
	widget = block_make(map[Property]Value{}, allocator) or_return
	widget.type = .Viewport

	return widget, true
}

viewport_draw :: proc(renderer: ^Renderer, widget: ^Widget) {
	assert(widget.type == .Viewport, "Expected widget to be a viewport")

	box_draw(renderer, widget, 1)
}
