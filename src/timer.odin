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

	timer_data.fd, _ = timerfd_create(.MONOTONIC, {.NONBLOCK})
	interval_spec := durtation_to_timespec(interval)
	itimerspec := linux.ITimer_Spec {
		interval = interval_spec,
		value    = durtation_to_timespec(delay) if delay != -1 else interval_spec,
	}
	timerfd_settime(timer_data.fd, nil, &itimerspec, nil)

	timer.current_id += 1

	append(&timer.fds, timer_data)

	return timer_data.id
}

timer_stop :: proc(timer: ^Timer, id: Timer_Id) -> bool {
	for fd_data, i in timer.fds {
		if fd_data.id == id {
			itimerspec := linux.ITimer_Spec{}
			timerfd_settime(fd_data.fd, nil, &itimerspec, nil)

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


@(private)
errno_unwrap2 :: #force_inline proc "contextless" (ret: $P, $T: typeid) -> (T, linux.Errno) {
	if ret < 0 {
		default_value: T
		return default_value, linux.Errno(-ret)
	} else {
		return T(ret), linux.Errno(.NONE)
	}
}

timerfd_create :: proc(clock_id: linux.Clock_Id, flags: linux.Open_Flags) -> (linux.Fd, linux.Errno) {
	ret := cast(linux.Fd)linux.syscall(linux.SYS_timerfd_create, clock_id, transmute(u32)flags)
	return errno_unwrap2(ret, linux.Fd)
}

@(private)
timerfd_settime :: proc(
	fd: linux.Fd,
	flags: linux.ITimer_Flags,
	new_value: ^linux.ITimer_Spec,
	old_value: ^linux.ITimer_Spec,
) -> linux.Errno {
	ret := linux.syscall(linux.SYS_timerfd_settime, fd, transmute(u32)flags, new_value, old_value)
	return linux.Errno(-ret)
}

@(private)
timerfd_gettime :: proc(fd: linux.Fd, curr_value: ^linux.ITimer_Spec) -> linux.Errno {
	ret := linux.syscall(linux.SYS_timerfd_gettime, fd, curr_value)
	return linux.Errno(-ret)
}
