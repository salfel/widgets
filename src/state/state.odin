package state

import "../css"
import "base:runtime"
import "vendor:glfw"

app_state: App_State

App_State :: struct {
	window_size: [2]f32,
	css:         css.Ast,
	ctx:         runtime.Context,
}
