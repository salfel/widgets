package main

import "base:runtime"
import "core:fmt"

global_ctx: runtime.Context

App_Context :: struct {
	window:         Window_Context,
	event_manager:  Event_Manager,
	widget_manager: Widget_Manager,
	input:          Input,
	renderer:       Renderer,
}

Window_Context :: struct {
	wl:   Wayland_State,
	egl:  Egl_State,
	size: [2]f32,
}

app_context_init :: proc(app_context: ^App_Context, title, app_id: cstring) {
	global_ctx = context

	wl_init(app_context, app_id, title)
	egl_init(&app_context.window)

	widget_manager_init(&app_context.widget_manager)
	event_manager_init(&app_context.event_manager)
	renderer_init(&app_context.renderer)
}

app_context_destroy :: proc(app_context: ^App_Context) {
	widget_manager_destroy(&app_context.widget_manager)
	event_manager_destroy(&app_context.event_manager)
}
