package main

import "base:runtime"
import "core:fmt"
import "core:sync"
import "core:sys/linux"

App_Context :: struct {
	window:                 Window_Context,
	event_manager:          Event_Manager,
	widget_manager:         Widget_Manager,
	async_resource_manager: Async_Resource_Manager,
	input:                  Input,
	renderer:               Renderer,
	ctx:                    runtime.Context,
}

Window_Context :: struct {
	wl:   Wayland_State,
	egl:  Egl_State,
	size: [2]f32,
}

app_context_init :: proc(app_context: ^App_Context, title, app_id: cstring) -> bool {
	app_context.ctx = context

	wl_init(app_context, app_id, title)
	egl_init(&app_context.window)

	widget_manager_init(&app_context.widget_manager)
	event_manager_init(&app_context.event_manager)
	async_resource_manager_init(&app_context.async_resource_manager)
	input_init(&app_context.input)
	renderer_init(&app_context.renderer)

	pipe_fds: [2]linux.Fd
	if err := linux.pipe2(&pipe_fds, nil); err != nil {
		fmt.println("pipe error", err)
		return false
	}

	app_context.renderer.fd = pipe_fds[0]
	sync.guard(&app_context.async_resource_manager.mutex)
	app_context.async_resource_manager.fd = pipe_fds[1]

	return true
}

app_context_destroy :: proc(app_context: ^App_Context) {
	widget_manager_destroy(&app_context.widget_manager)
	event_manager_destroy(&app_context.event_manager)
	async_resource_manager_destroy(&app_context.async_resource_manager)
	input_destroy(&app_context.input)
}
