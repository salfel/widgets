package main

import "base:runtime"

App_Context :: struct {
	window:         Window_Context,
	event_manager:  Event_Manager,
	widget_manager: Widget_Manager,
	input:          Input,
	timer:          Timer,
	renderer:       Renderer,
	ctx:            runtime.Context,
}

Window_Context :: struct {
	wl:   Wayland_State,
	egl:  Egl_State,
	size: [2]f32,
}

app_context_init :: proc(app_context: ^App_Context, title, app_id: cstring) {
	app_context.ctx = context

	wl_init(app_context, app_id, title)
	egl_init(&app_context.window)

	widget_manager_init(&app_context.widget_manager)
	event_manager_init(&app_context.event_manager)
	timer_init(&app_context.timer)
	renderer_init(&app_context.renderer)
}

app_context_destroy :: proc(app_context: ^App_Context) {
	wl_destroy(&app_context.window.wl)

	widget_manager_destroy(&app_context.widget_manager)
	event_manager_destroy(&app_context.event_manager)
	timer_destroy(&app_context.timer)
}
