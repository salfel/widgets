package main

import "core:math"
import "core:testing"

Sides :: struct {
	left, right, top, bottom: f32,
}

Layout_Property :: enum {
	Expand_Horizontal,
	Expand_Vertical,
}

Axis :: struct {
	min, preferred: f32,
}

axis_make :: proc {
	axis_make_fixed,
}

axis_make_fixed :: proc(value: f32) -> Axis {
	return Axis{min = value, preferred = value}
}

Layout_Style :: struct {
	size:            [2]Axis,
	padding, margin: Sides,
	border:          f32,
	properties:      bit_set[Layout_Property],
}

Box_Direction :: enum {
	Horizontal,
	Vertical,
}

Layout_Box :: struct {
	direction: Box_Direction,
}

Layout_Type :: enum {
	Box,
}

Layout :: struct {
	style:        Layout_Style,
	children:     [dynamic]^Layout,
	parent:       ^Layout,

	// internal
	type:         Layout_Type,
	data:         union {
		Layout_Box,
	},

	// intermediate
	intermediate: struct {
		constraints: Axis,
		size:        f32,
	},

	// result
	size:         [2]f32,
	position:     [2]f32,
	overflow:     bool,
	dirty:        bool,
}

layout_make :: proc(allocator := context.allocator) -> Layout {
	return Layout{children = make([dynamic]^Layout, allocator)}
}

layout_destroy :: proc(layout: ^Layout) {
	delete(layout.children)
}

layout_measure :: proc(layout: ^Layout) {
	layout.intermediate.constraints = layout.style.size.x

	// TODO: use both axis
	child_axis: [1]Axis

	child_height: f32 = 0

	for child in layout.children {
		layout_measure(child)

		child_axis.x.min +=
			child.intermediate.constraints.min +
			child.style.margin.left +
			child.style.margin.right +
			2 * child.style.border
		child_axis.x.preferred +=
			child.intermediate.constraints.preferred +
			child.style.margin.left +
			child.style.margin.right +
			2 * child.style.border

		child_height = math.max(child_height, child.size.y + child.style.margin.top + child.style.margin.bottom)
	}

	layout.intermediate.constraints.min =
		math.max(
			layout.intermediate.constraints.min,
			child_axis.x.min + layout.style.padding.left + layout.style.padding.right,
		) +
		2 * layout.style.border

	layout.intermediate.constraints.preferred =
		math.max(
			layout.intermediate.constraints.preferred,
			child_axis.x.preferred + layout.style.padding.left + layout.style.padding.right,
		) +
		2 * layout.style.border

	layout.intermediate.size = layout.intermediate.constraints.preferred

	layout.size.y =
		math.max(
			layout.style.size.y.preferred,
			child_height + layout.style.padding.top + layout.style.padding.bottom,
		) +
		2 * layout.style.border
}

layout_compute :: proc(layout: ^Layout, available: f32, allocator := context.allocator) {
	layout.dirty = layout.size.x != available
	layout.size.x = math.max(layout.intermediate.constraints.min, available)

	// shrink
	if layout.intermediate.constraints.preferred > available && len(layout.children) > 0 {
		space_left := layout.intermediate.constraints.preferred - available

		available_children := make_dynamic_array_len_cap([dynamic]^Layout, 0, len(layout.children), allocator)
		defer delete(available_children)
		for child in layout.children {
			append(&available_children, child)
		}

		for space_left > 0 {
			min_distance: f32 = math.F32_MAX

			if len(available_children) == 0 {
				layout.overflow = true
				break
			}

			#reverse for child, i in available_children {
				if child.intermediate.size <= child.intermediate.constraints.min {
					assert(
						child.intermediate.size == child.intermediate.constraints.min,
						"child size should never be smaller than min",
					)

					unordered_remove(&available_children, i)
				}

				min_distance = math.min(min_distance, child.intermediate.size - child.intermediate.constraints.min)
			}

			space_left -= min_distance * f32(len(available_children))

			for &child in available_children {
				child.intermediate.size -= min_distance
			}
		}
	}

	// grow
	if layout.intermediate.constraints.preferred < available && len(layout.children) > 0 {
		space_left := available - layout.intermediate.constraints.preferred

		expandable := 0
		for child in layout.children {
			if .Expand_Horizontal in child.style.properties do expandable += 1
		}

		available_children := make_dynamic_array_len_cap([dynamic]^Layout, 0, expandable, allocator)
		defer delete(available_children)

		for child in layout.children {
			if .Expand_Horizontal in child.style.properties do append(&available_children, child)
		}

		space_per_child := space_left / f32(len(available_children)) if len(available_children) > 0 else 0

		for child in available_children {
			child.intermediate.size += space_per_child
		}
	}

	for child in layout.children {
		layout_compute(child, child.intermediate.size)
	}
}

layout_arrange :: proc(layout: ^Layout, offset: [2]f32 = {0, 0}) {
	offset := offset + {layout.style.margin.left, layout.style.margin.top}

	layout.dirty |= layout.position != offset
	layout.position = offset

	offset += {layout.style.padding.left, layout.style.padding.top} + layout.style.border

	for child in layout.children {
		layout_arrange(child, offset)

		offset.x += child.size.x + child.style.margin.left + child.style.margin.right
	}
}

@(test)
test_layout_compute_shrink :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	append(&parent.children, &child1)
	append(&parent.children, &child2)

	parent.style.padding.left = 30

	child1.style.size.x.preferred = 100
	child1.style.size.x.min = 100
	child1.style.padding.left = 30

	child2.style.size.x.preferred = 200
	child2.style.size.x.min = 100
	child2.style.margin.left = 30

	layout_measure(&parent)
	layout_compute(&parent, 300)

	testing.expect_value(t, child1.size.x, 100)
	testing.expect_value(t, child2.size.x, 100)
	testing.expect_value(t, parent.size.x, 300)
}

@(test)
test_layout_compute_overflow :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	append(&parent.children, &child1, &child2)

	parent.style.padding.left = 30
	parent.style.padding.right = 30

	child1.style.size.x.preferred = 100
	child1.style.size.x.min = 100
	child1.style.padding.left = 30

	child2.style.size.x.preferred = 200
	child2.style.size.x.min = 100
	child2.style.margin.left = 30

	layout_measure(&parent)
	layout_compute(&parent, 200)

	testing.expect_value(t, parent.overflow, true)
}

@(test)
test_layout_compute_expand :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	child3 := layout_make()
	append(&parent.children, &child1, &child2, &child3)

	parent.style.padding.left = 30
	parent.style.padding.right = 30

	child1.style.size.x.preferred = 100
	child1.style.properties += {.Expand_Horizontal}

	child2.style.size.x.preferred = 200
	child2.style.margin.left = 30
	child2.style.properties += {.Expand_Horizontal}

	child3.style.size.x.preferred = 300

	layout_measure(&parent)
	layout_compute(&parent, 800)

	testing.expect_value(t, child1.size.x, 155)
	testing.expect_value(t, child2.size.x, 255)
	testing.expect_value(t, child3.size.x, 300)
}

@(test)
test_layout_arrange :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	append(&parent.children, &child1, &child2)

	parent.style.margin.left = 30
	parent.style.padding.left = 30
	parent.style.padding.top = 10

	child1.style.size.y.preferred = 100
	child1.style.size.x.preferred = 100
	child1.style.padding.left = 30

	child2.style.size.y.preferred = 50
	child2.style.size.x.preferred = 200
	child2.style.margin.left = 30

	layout_measure(&parent)
	layout_compute(&parent, 500)
	layout_arrange(&parent)

	testing.expect_value(t, parent.position.x, 30)
	testing.expect_value(t, parent.position.y, 0)
	testing.expect_value(t, parent.size.y, 110)

	testing.expect_value(t, child1.position.x, 60)
	testing.expect_value(t, child1.position.y, 10)
	testing.expect_value(t, child1.size.y, 100)

	testing.expect_value(t, child2.position.x, 190)
	testing.expect_value(t, child2.position.y, 10)
	testing.expect_value(t, child2.size.y, 50)
}
