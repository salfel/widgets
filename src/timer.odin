package main

import "base:runtime"
import "core:sys/linux"
import "core:time"

Timer_Id :: distinct uint

Timer :: struct {
	allocator:  runtime.Allocator,
	fds:        [dynamic]Timer_Data,
	current_id: Timer_Id,
}

Timer_Data :: struct {
	id:      Timer_Id,
	fd:      linux.Fd,
	handler: proc(data: rawptr),
	data:    rawptr,
}

timer_init :: proc(timer: ^Timer, allocator := context.allocator) {
	timer.allocator = allocator
	timer.fds = make([dynamic]Timer_Data, allocator)
}

timer_destroy :: proc(timer: ^Timer) {
	delete(timer.fds)
}

timer_set_interval :: proc(
	timer: ^Timer,
	handler: proc(data: rawptr),
	data: rawptr,
	interval: time.Duration,
	delay: time.Duration = -1,
) -> Timer_Id {
	timer_data := Timer_Data {
		id      = timer.current_id,
		handler = handler,
		data    = data,
	}

	timer_data.fd, _ = linux.timerfd_create(.MONOTONIC, {.NONBLOCK})
	interval_spec := durtation_to_timespec(interval)
	itimerspec := linux.ITimer_Spec {
		interval = interval_spec,
		value    = durtation_to_timespec(delay) if delay != -1 else interval_spec,
	}
	linux.timerfd_settime(timer_data.fd, nil, &itimerspec, nil)

	timer.current_id += 1

	append(&timer.fds, timer_data)

	return timer_data.id
}

timer_stop :: proc(timer: ^Timer, id: Timer_Id) -> bool {
	for fd_data, i in timer.fds {
		if fd_data.id == id {
			itimerspec := linux.ITimer_Spec{}
			linux.timerfd_settime(fd_data.fd, nil, &itimerspec, nil)

			unordered_remove(&timer.fds, i)

			return true
		}
	}

	return false
}

@(private)
durtation_to_timespec :: proc(duration: time.Duration) -> linux.Time_Spec {
	return linux.Time_Spec {
		time_sec = cast(uint)(duration / time.Second),
		time_nsec = cast(uint)(duration % time.Second),
	}
}
