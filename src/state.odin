package main

import "css"
import "vendor:glfw"

app_state: App_State

App_State :: struct {
	window_size:      [2]f32,
	css:              css.Ast,
	glyph_repository: Glyph_Repository,
}
