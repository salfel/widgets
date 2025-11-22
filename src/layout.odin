package main

import "core:math"
import "core:testing"

Layout_Property :: enum {
	Expand_Horizontal,
	Expand_Vertical,
}

Layout_Constraint :: struct {
	min, preferred: f32,
}

layout_constraint_make :: proc {
	layout_constraint_make_fixed,
}

layout_constraint_make_fixed :: proc(value: f32) -> Layout_Constraint {
	return Layout_Constraint{min = value, preferred = value}
}

Layout_Style :: struct {
	size:            [2]Layout_Constraint,
	padding, margin: Sides,
	border:          f32,
	properties:      bit_set[Layout_Property],
}

Axis :: enum {
	Horizontal,
	Vertical,
}

axis_opposite :: proc(axis: Axis) -> Axis {
	return .Vertical if axis == .Horizontal else .Horizontal
}

Layout :: struct {
	style:          Layout_Style,
	children:       [dynamic]^Layout,
	parent:         ^Layout,
	axis:           Axis,

	// internal
	intermediate:   struct {
		constraint: [Axis]Layout_Constraint,
		size:       [Axis]f32,
	},

	// result
	size, position: [2]f32,
	overflow:       bool,
}

layout_make :: proc(axis: Axis = .Horizontal, allocator := context.allocator) -> Layout {
	return Layout{children = make([dynamic]^Layout, allocator), axis = axis}
}

layout_destroy :: proc(layout: ^Layout) {
	delete(layout.children)
}

layout_measure :: proc(layout: ^Layout) {
	child_constraints: [Axis]Layout_Constraint

	for child in layout.children {
		layout_measure(child)

		// main axis
		child_constraints[layout.axis].min +=
			child.intermediate.constraint[layout.axis].min + sides_axis(child.style.margin, layout.axis)
		child_constraints[layout.axis].preferred +=
			child.intermediate.constraint[layout.axis].preferred + sides_axis(child.style.margin, layout.axis)

		// cross axis
		child_constraints[axis_opposite(layout.axis)].min = math.max(
			child_constraints[axis_opposite(layout.axis)].min,
			child.intermediate.constraint[axis_opposite(layout.axis)].min +
			sides_axis(child.style.margin, axis_opposite(layout.axis)),
		)
		child_constraints[axis_opposite(layout.axis)].preferred = math.max(
			child_constraints[axis_opposite(layout.axis)].preferred,
			child.intermediate.constraint[axis_opposite(layout.axis)].preferred +
			sides_axis(child.style.margin, axis_opposite(layout.axis)),
		)
	}

	for axis in Axis {
		layout.intermediate.constraint[axis].min =
			math.max(
				child_constraints[axis].min + sides_axis(layout.style.padding, axis),
				layout.style.size[axis].min,
			) +
			2 * layout.style.border

		layout.intermediate.constraint[axis].preferred =
			math.max(
				child_constraints[axis].preferred + sides_axis(layout.style.padding, axis),
				layout.style.size[axis].preferred,
			) +
			2 * layout.style.border

		layout.intermediate.size[axis] = layout.intermediate.constraint[axis].preferred
	}
}

layout_compute :: proc(layout: ^Layout, available: Maybe(f32) = nil) {
	available := available.(f32) if available != nil else layout.intermediate.size[layout.axis]

	if layout.axis == .Horizontal {
		layout.size.x = math.clamp(available, layout.intermediate.constraint[.Horizontal].min, math.F32_MAX)
		layout.size.y = layout.intermediate.size[.Vertical]
	} else {
		layout.size.y = math.clamp(available, layout.intermediate.constraint[.Vertical].min, math.F32_MAX)
		layout.size.x = layout.intermediate.size[.Horizontal]
	}

	// shrink
	if layout.intermediate.constraint[layout.axis].preferred > available && len(layout.children) > 0 {
		space_left := layout.intermediate.constraint[layout.axis].preferred - available

		available_children := make_dynamic_array_len_cap([dynamic]^Layout, 0, len(layout.children), context.allocator)
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
				if child.intermediate.size[layout.axis] <= child.intermediate.constraint[layout.axis].min {
					assert(
						child.intermediate.size[layout.axis] == child.intermediate.constraint[layout.axis].min,
						"child size should never be below minimum",
					)

					unordered_remove(&available_children, i)

					continue
				}

				min_distance = math.min(
					min_distance,
					child.intermediate.size[layout.axis] - child.intermediate.constraint[layout.axis].min,
				)
			}

			min_distance = math.min(
				space_left / f32(len(available_children)) if len(available_children) > 0 else 0,
				min_distance,
			)

			space_left -= min_distance * f32(len(available_children))

			for &child in available_children {
				child.intermediate.size[layout.axis] -= min_distance
			}
		}
	}

	// grow
	if layout.intermediate.constraint[layout.axis].preferred < available && len(layout.children) > 0 {
		space_left := available - layout.intermediate.constraint[layout.axis].preferred

		expandable := 0
		for child in layout.children {
			if layout.axis == .Horizontal && .Expand_Horizontal in child.style.properties ||
			   layout.axis == .Vertical && .Expand_Vertical in child.style.properties {
				expandable += 1
			}
		}

		available_children := make_dynamic_array_len_cap([dynamic]^Layout, 0, expandable, context.allocator)
		defer delete(available_children)

		for child in layout.children {
			if layout.axis == .Horizontal && .Expand_Horizontal in child.style.properties ||
			   layout.axis == .Vertical && .Expand_Vertical in child.style.properties {
				append(&available_children, child)
			}
		}

		for space_left > 0 && len(available_children) > 0 {
			smallest, second_smallest: f32 = math.F32_MAX, math.F32_MAX
			smallest_count := 0

			for child in available_children {
				if child.intermediate.size[layout.axis] < smallest {
					second_smallest = smallest
					smallest = child.intermediate.size[layout.axis]
				} else if child.intermediate.size[layout.axis] < second_smallest &&
				   child.intermediate.size[layout.axis] > smallest {
					second_smallest = child.intermediate.size[layout.axis]
				}
			}

			for child in available_children {
				if child.intermediate.size[layout.axis] == smallest do smallest_count += 1
			}

			distance := math.min(space_left / f32(smallest_count), second_smallest - smallest)

			for child in available_children {
				if child.intermediate.size[layout.axis] == smallest {
					child.intermediate.size[layout.axis] += distance
					space_left -= distance
				}
			}
		}
	}

	// expand cross axis
	for child in layout.children {
		if layout.axis == .Horizontal && .Expand_Vertical in child.style.properties ||
		   layout.axis == .Vertical && .Expand_Horizontal in child.style.properties {
			child.intermediate.size[axis_opposite(layout.axis)] = math.max(
				child.intermediate.size[axis_opposite(layout.axis)],
				layout.intermediate.size[axis_opposite(layout.axis)] -
				sides_axis(layout.style.padding, axis_opposite(layout.axis)) -
				2 * layout.style.border -
				sides_axis(child.style.margin, axis_opposite(layout.axis)),
			)
		}
	}

	for child in layout.children {
		layout_compute(child)
	}
}

layout_arrange :: proc(layout: ^Layout, offset: [2]f32 = {}) {
	layout.position = offset + {layout.style.margin.left, layout.style.margin.top}
	offset := layout.position
	offset += {layout.style.border + layout.style.padding.left, layout.style.border + layout.style.padding.top}

	for child in layout.children {
		layout_arrange(child, offset)

		if layout.axis == .Horizontal {
			offset.x += child.size.x + sides_axis(child.style.margin, .Horizontal)
		} else {
			offset.y += child.size.y + sides_axis(child.style.margin, .Vertical)
		}
	}
}

@(test)
test_layout_measure :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	append(&parent.children, &child1, &child2)

	parent.style.padding.left = 30

	child1.style.size.y.preferred = 100
	child1.style.size.x.preferred = 100
	child1.style.padding.left = 30

	child2.style.size.y.preferred = 200
	child2.style.size.x.preferred = 50

	layout_measure(&parent)

	testing.expect_value(t, parent.intermediate.constraint[.Horizontal].min, 60)
	testing.expect_value(t, parent.intermediate.constraint[.Horizontal].preferred, 180)
	testing.expect_value(t, parent.intermediate.constraint[.Vertical].min, 0)
	testing.expect_value(t, parent.intermediate.constraint[.Vertical].preferred, 200)
}

@(test)
test_layout_compute :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	append(&parent.children, &child1, &child2)

	parent.style.padding.left = 30
	parent.style.padding.bottom = 30

	child1.style.size.y.preferred = 100
	child1.style.size.x.preferred = 100
	child1.style.padding.left = 30

	child2.style.size.y.preferred = 200
	child2.style.size.x.preferred = 50

	layout_measure(&parent)
	layout_compute(&parent, 300)

	testing.expect_value(t, parent.size.x, 300)
	testing.expect_value(t, child1.size.x, 100)
	testing.expect_value(t, child2.size.x, 50)

	testing.expect_value(t, parent.size.y, 230)
	testing.expect_value(t, child1.size.y, 100)
	testing.expect_value(t, child2.size.y, 200)
}

@(test)
test_layout_compute_cross_axis :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	append(&parent.children, &child1, &child2)

	parent.style.padding.left = 30
	parent.style.padding.bottom = 30

	child1.style.size.y.preferred = 100
	child1.style.size.x.preferred = 100
	child1.style.padding.left = 30
	child1.style.properties += {.Expand_Vertical}

	child2.style.size.y.preferred = 150
	child2.style.size.x.preferred = 50
	child2.style.margin.top = 50

	layout_measure(&parent)
	layout_compute(&parent, 300)

	testing.expect_value(t, parent.size.x, 300)
	testing.expect_value(t, child1.size.x, 100)
	testing.expect_value(t, child2.size.x, 50)

	testing.expect_value(t, parent.size.y, 230)
	testing.expect_value(t, child1.size.y, 200)
	testing.expect_value(t, child2.size.y, 150)
}

@(test)
test_layout_compute_shrink :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	append(&parent.children, &child1, &child2)

	parent.style.padding.left = 30

	child1.style.size.x.preferred = 100
	child1.style.size.x.min = 100
	child1.style.padding.left = 30

	child2.style.size.x.preferred = 250
	child2.style.margin.left = 50

	layout_measure(&parent)
	layout_compute(&parent, 300)

	testing.expect_value(t, parent.size.x, 300)
	testing.expect_value(t, child1.size.x, 100)
	testing.expect_value(t, child2.size.x, 120)
}

@(test)
test_layout_compute_grow :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	child3 := layout_make()
	append(&parent.children, &child1, &child2, &child3)

	child1.style.size.x.preferred = 100
	child1.style.properties += {.Expand_Horizontal}

	child2.style.size.x.preferred = 200
	child2.style.properties += {.Expand_Horizontal}

	child3.style.size.x.preferred = 250
	child3.style.properties += {.Expand_Horizontal}

	layout_measure(&parent)
	layout_compute(&parent, 900)

	testing.expect_value(t, parent.size.x, 900)
	testing.expect_value(t, child1.size.x, 300)
	testing.expect_value(t, child2.size.x, 300)
	testing.expect_value(t, child3.size.x, 300)
}

@(test)
test_layout_arrange :: proc(t: ^testing.T) {
	parent := layout_make()
	defer layout_destroy(&parent)

	child1 := layout_make()
	child2 := layout_make()
	append(&parent.children, &child1, &child2)

	parent.style.padding.left = 30
	parent.style.padding.right = 30
	parent.style.padding.top = 10

	child1.style.size.x.preferred = 100
	child1.style.size.y.preferred = 200
	child1.style.size.x.min = 100
	child1.style.padding.left = 30

	child2.style.size.x.preferred = 200
	child2.style.size.y.preferred = 100
	child2.style.margin.left = 30
	child2.style.margin.top = 30

	layout_measure(&parent)
	layout_compute(&parent, 500)
	layout_arrange(&parent)

	testing.expect_value(t, parent.position.x, 0)
	testing.expect_value(t, parent.position.y, 0)
	testing.expect_value(t, parent.size.x, 500)
	testing.expect_value(t, parent.size.y, 210)

	testing.expect_value(t, child1.position.x, 30)
	testing.expect_value(t, child1.position.y, 10)

	testing.expect_value(t, child2.position.x, 160)
	testing.expect_value(t, child2.position.y, 40)
}
