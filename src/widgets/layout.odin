package widgets

import "core:fmt"
import "core:math"
import "core:mem"
import "core:testing"

Layout :: struct {
	min:       f32,
	preferred: f32,
	max:       f32,
	padding:   struct {
		left:   f32,
		right:  f32,
		top:    f32,
		bottom: f32,
	},
	margin:    struct {
		left:   f32,
		right:  f32,
		top:    f32,
		bottom: f32,
	},
	result:    struct {
		size:     [2]f32,
		position: [2]f32,
		clip:     bool,
	},
	children:  [dynamic]^Layout,
}

layout_make :: proc(min: f32, preferred: f32, max: f32 = math.INF_F32, allocator := context.allocator) -> Layout {
	return Layout {
		min = min,
		preferred = preferred,
		max = max,
		padding = {left = 0, right = 0, top = 0, bottom = 0},
		margin = {left = 0, right = 0, top = 0, bottom = 0},
		result = {size = {0, -1}, position = {0, 0}, clip = false},
		children = make([dynamic]^Layout, allocator),
	}
}

layout_destroy :: proc(layout: ^Layout) {
	delete(layout.children)
}

layout_measure :: proc(layout: ^Layout) {
	min: f32 = 0
	preferred: f32 = 0
	max: f32 = 0
	height: f32 = 0

	for &child in layout.children {
		layout_measure(child)

		min += child.min
		preferred += child.preferred

		if max != math.INF_F32 {
			if child.max != math.INF_F32 {
				max += child.max
			} else {
				max = math.INF_F32
			}
		}

		height = math.max(height, child.result.size.y)
	}

	if layout.result.size.y == -1 {
		layout.result.size.y = height
	} else if height > layout.result.size.y - layout.padding.top - layout.padding.bottom {
		layout.result.clip = true
	}

	layout.min = math.max(min + layout.padding.left + layout.padding.right, layout.min)
	layout.preferred = math.max(preferred + layout.padding.left + layout.padding.right, layout.preferred)
}

layout_min :: proc(layout: ^Layout) -> f32 {
	return layout.min + layout.margin.left + layout.margin.right
}

layout_preferred :: proc(layout: ^Layout) -> f32 {
	return layout.preferred + layout.margin.left + layout.margin.right
}

layout_max :: proc(layout: ^Layout) -> f32 {
	return layout.max + layout.margin.left + layout.margin.right
}

layout_compute :: proc(layout: ^Layout, width: f32, allocator := context.allocator) {
	layout.result.size.x = width

	for &child in layout.children {
		child.result.size.x = child.preferred
	}

	// shrink
	if layout_preferred(layout) > width {
		available := layout_preferred(layout) - width
		available_children := make([dynamic]^Layout, allocator)
		append(&available_children, ..layout.children[:])
		defer delete(available_children)

		for len(available_children) > 0 && available > 0 {
			min_distance := math.INF_F32
			#reverse for child, i in available_children {
				if child.result.size.x - layout_min(child) <= 0 {
					assert(child.result.size.x == layout_min(child), "expected child width to be equal to min")
					unordered_remove(&available_children, i)
					continue
				}

				distance := child.result.size.x - layout_min(child)
				min_distance = math.min(min_distance, distance)
			}

			min_distance =
				math.min(min_distance * f32(len(available_children)), available) / f32(len(available_children))

			for &child in available_children {
				child.result.size.x -= min_distance
				available -= min_distance
			}
		}
	}

	// grow
	if layout_preferred(layout) < width {
		available := width - layout_preferred(layout)
		available_children := make([dynamic]^Layout, allocator)
		append(&available_children, ..layout.children[:])
		defer delete(available_children)

		for len(available_children) > 0 && available > 0 {
			min_distance := math.INF_F32

			#reverse for child, i in available_children {
				if child.result.size.x - layout_max(child) >= 0 {
					assert(child.result.size.x == layout_max(child), "expected child width to be equal to max")
					unordered_remove(&available_children, i)
					continue
				}

				distance := child.max - child.result.size.x
				min_distance = math.min(min_distance, distance)
			}

			min_distance =
				math.min(min_distance * f32(len(available_children)), available) / f32(len(available_children))

			for &child in available_children {
				child.result.size.x += min_distance
				available -= min_distance
			}
		}
	}

	for &child in layout.children {
		layout_compute(child, child.result.size.x)
	}

	layout.result.size.x -= layout.margin.left + layout.margin.right
}

layout_arrange :: proc(layout: ^Layout) {
	offset: f32 = layout.result.position.x

	for &child in layout.children {
		child.result.position.x = layout.padding.left + child.margin.left + offset
		child.result.position.y = layout.result.position.y + child.margin.top + layout.padding.top
		offset += child.result.size.x + child.margin.left + child.margin.right

		layout_arrange(child)
	}
}

@(test)
test_layout_measure :: proc(t: ^testing.T) {
	layout := layout_make(100, 200)
	defer layout_destroy(&layout)
	children := []Layout{layout_make(100, 200), layout_make(100, 200)}
	for &child in children {
		append(&layout.children, &child)
	}

	layout_measure(&layout)
	testing.expect(t, layout.min == 200)
	testing.expect(t, layout.preferred == 400)
}

@(test)
test_layout_compute_shrink :: proc(t: ^testing.T) {
	layout := layout_make(0, 0)
	defer layout_destroy(&layout)

	children := []Layout{layout_make(50, 200), layout_make(180, 200)}
	for &child in children {
		append(&layout.children, &child)
	}

	layout_measure(&layout)
	layout_compute(&layout, 300)

	testing.expect(t, layout.children[0].result.size.x == 120)
	testing.expect(t, layout.children[1].result.size.x == 180)
}

@(test)
test_layout_compute_grow :: proc(t: ^testing.T) {
	layout := layout_make(0, 0)
	defer layout_destroy(&layout)

	child1 := layout_make(100, 200, 220)
	child2 := layout_make(100, 200)
	append(&layout.children, &child1)
	append(&layout.children, &child2)

	layout_measure(&layout)
	testing.expect(t, layout.min == 200)
	testing.expect(t, layout.preferred == 400)

	layout_compute(&layout, 500)

	testing.expect(t, layout.children[0].result.size.x == 220)
	testing.expect(t, layout.children[1].result.size.x == 280)
}

@(test)
test_layout_arrange :: proc(t: ^testing.T) {
	layout := layout_make(0, 0)
	layout.padding.left = 100
	defer layout_destroy(&layout)

	child1 := layout_make(100, 200, 220)
	child2 := layout_make(100, 200)
	child2.margin.left = 100
	append(&layout.children, &child1)
	append(&layout.children, &child2)

	layout_measure(&layout)
	layout_compute(&layout, 500)
	layout_arrange(&layout)

	testing.expect(t, child1.result.position.x == 100)
	testing.expect(t, child2.result.position.x == 200)
}
