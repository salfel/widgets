package state

import "vendor:glfw"

app_state: App_State

App_State :: struct {
	window: struct {
		width, height: f32,
	},
}
