package libgraph

import "core:container/priority_queue"
import "core:slice"

import "core:fmt"
import "core:math/linalg"
import "core:mem"
Vec3 :: linalg.Vector3f64
Node :: struct {
	pos:   Vec3,
	edges: [dynamic]^Node,
}

Graph :: struct {
	nodes:                          [dynamic]^Node,
	allocator:                      mem.Allocator,
	arena:                          mem.Dynamic_Arena,
	identical_node_distance_thresh: f64,
}

create_graph :: proc() -> ^Graph {
	out := new(Graph)
	mem.dynamic_arena_init(&out.arena)
	out.allocator = mem.dynamic_arena_allocator(&out.arena)
	return out
}


destroy_graph :: proc(this: ^Graph) {
	mem.dynamic_arena_destroy(&this.arena)
	delete(this.nodes)
	free(this)
}

create_node :: proc(this: ^Graph, pos: Vec3) -> ^Node {
	out := new(Node, this.allocator)
	out.edges = make([dynamic]^Node, this.allocator)
	out.pos = pos
	append(&this.nodes, out)
	return out
}

connect_nodes :: proc(this: ^Graph, start: ^Node, end: ^Node) {
	if start == end {
		return
	}
	{
		hit := false
		for i in start.edges {
			if i == end {
				hit = true
				break
			}
		}
		if !hit {
			append(&start.edges, end)
		}
	}
	{
		hit := false
		for i in end.edges {
			if i == start {
				hit = true
				break
			}
		}
		if !hit {
			append(&end.edges, start)
		}
	}
}


disconnect_nodes :: proc(this: ^Graph, start: ^Node, end: ^Node) {
	if start == end {
		return
	}
	for {
		hit := -1
		for i, idx in start.edges {
			if i == end {
				hit = idx
				break
			}
		}
		if hit != -1 {
			unordered_remove(&start.edges, hit)
		} else {
			break
		}
	}
	for {
		hit := -1
		for i, idx in end.edges {
			if i == start {
				hit = idx
				break
			}
		}
		if hit != -1 {
			unordered_remove(&end.edges, hit)
		} else {
			break
		}
	}
}

get_nearest_node :: proc(this: ^Graph, pos: Vec3) -> (^Node, f64) {
	if len(this.nodes) == 0 {
		return nil, -1.
	}
	nearest: ^Node = this.nodes[0]
	dist := linalg.distance(this.nodes[0].pos, pos)
	if len(this.nodes) == 1 {
		return nearest, dist
	}
	for i in this.nodes[1:] {
		d2 := linalg.distance(i.pos, pos)
		if d2 < dist {
			dist = d2
			nearest = i
		}
	}
	return nearest, dist
}

get_node_at :: proc(this: ^Graph, pos: Vec3, eq_dist := 1.) -> ^Node {
	ptr, dist := get_nearest_node(this, pos)
	if dist > eq_dist || ptr == nil {
		return create_node(this, pos)
	}
	return ptr
}

//https://en.wikipedia.org/wiki/A*_search_algorithm
/*
	https://en.wikipedia.org/wiki/A*_search_algorithm
	function a_star(start, goal, h)
    // The set of discovered nodes that may need to be (re-)expanded.
    // Initially, only the start node is known.
    // This is usually implemented as a min-heap or priority queue rather than a hash-set.
    open_set := {start}

    // For node n, came_from[n] is the node immediately preceding it on the cheapest path from the start
    // to n currently known.
    came_from := an empty map

    // For node n, g_score[n] is the currently known cost of the cheapest path from start to n.
    g_score := map with default value of Infinity
    g_score[start] := 0

    // For node n, f_score[n] := g_score[n] + h(n). f_score[n] represents our current best guess as to
    // how cheap a path could be from start to finish if it goes through n.
    f_score := map with default value of Infinity
    f_score[start] := h(start)

    while open_set is not empty
        // This operation can occur in O(Log(N)) time if open_set is a min-heap or a priority queue
        current := the node in open_set having the lowest f_score[] value
        if current = goal
            return reconstruct_path(came_from, current)

        open_set.remove(current)
        for each neighbor of current
            // d(current,neighbor) is the weight of the edge from current to neighbor
            // tentative_g_score is the distance from start to the neighbor through current
            tentative_g_score := g_score[current] + d(current, neighbor)
            if tentative_g_score < g_score[neighbor]
                // This path to neighbor is better than any previous one. Record it!
                came_from[neighbor] := current
                g_score[neighbor] := tentative_g_score
                f_score[neighbor] := tentative_g_score + h(neighbor)
                if neighbor not in open_set
                    open_set.add(neighbor)

    // Open set is empty but goal was never reached
    return failure
	*/
@(fast_math = {
	.Allow_Reassoc,
	.No_NaNs,
	.No_Infs,
	.No_Signed_Zeros,
	.Allow_Reciprocal,
	.Allow_Contract,
})
pathfind_nodes :: proc(
	this: ^Graph,
	start: ^Node,
	end: ^Node,
	alloc: mem.Allocator = context.allocator,
) -> (
	path: []^Node,
	ok: bool,
) {

	reconstruct_path :: proc(
		came_from: map[^Node]^Node,
		current: ^Node,
		alloc: mem.Allocator,
	) -> [dynamic]^Node {
		current := current
		total_path := make([dynamic]^Node, alloc)
		append(&total_path, current)
		for (current in came_from) {
			current = came_from[current]
			append(&total_path, current)
		}
		slice.reverse(total_path[:])
		return total_path
	}
	heuristic := proc(a: ^Node, b: ^Node) -> f64 {
		return linalg.distance(a.pos, b.pos)
	}
	open_set: priority_queue.Priority_Queue(^Node)
	defer priority_queue.destroy(&open_set)
	priority_queue.init(&open_set, proc(a: ^Node, b: ^Node) -> bool {
		ptr := cast(^map[^Node]f64)context.user_ptr
		if a not_in ptr^ {
			return false
		}
		if b not_in ptr^ {
			return true
		}
		a_n := ptr^[a]
		b_n := ptr^[b]
		return a_n < b_n
	}, proc(list: []^Node, i, j: int) {
		tmp := list[i]
		list[i] = list[j]
		list[j] = tmp
	})
	open_set_set := make(map[^Node]u8)
	defer delete(open_set_set)
	g_score: map[^Node]f64 = make(map[^Node]f64)
	defer delete(g_score)
	g_score[start] = 0
	f_score: map[^Node]f64 = make(map[^Node]f64)
	defer delete(f_score)
	f_score[start] = heuristic(start, end)
	context.user_ptr = &f_score
	priority_queue.push(&open_set, start)
	open_set_set[start] = 0
	came_from: map[^Node]^Node = make(map[^Node]^Node)
	defer delete(came_from)
	for priority_queue.len(open_set) > 0 {
		current: ^Node = nil
		min_f: f64 = -1.
		current = priority_queue.pop(&open_set)
		delete_key(&open_set_set, current)
		if current == end {
			path = reconstruct_path(came_from, current, alloc)[:]
			ok = true
			return
		}
		for neighbor in current.edges {
			scr := 1000000000000000000.
			if current in g_score {
				scr = g_score[current]
			}
			tentative_g_score := scr + linalg.distance(current.pos, neighbor.pos)
			scr2 := 1000000000000000000.
			if neighbor in g_score {
				scr2 = g_score[neighbor]
			}
			if tentative_g_score < scr2 || (neighbor not_in g_score) {
				came_from[neighbor] = current
				g_score[neighbor] = tentative_g_score
				f_score[neighbor] = tentative_g_score + heuristic(neighbor, end)
				if neighbor not_in open_set_set {
					open_set_set[neighbor] = 0
					priority_queue.push(&open_set, neighbor)
				}
			}

		}
	}
	return
}
