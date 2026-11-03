package main
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "core:sys/posix"
import "core:time"

import "core:encoding/cbor"
import "game"
import "game/engine"
import "libgraph"
import "vendor:raylib"
//3,490,216
Vec3f :: engine.Vec3f
Vec3 :: engine.Vec3
Quat :: engine.Quat
main :: proc() {
	track := mem.Tracking_Allocator{}
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	test_main()
	for _, leak in track.allocation_map {
		fmt.printf("%v leaked %m\n", leak.location, leak.size)
	}
}

game_main :: proc() {
	engine.init()
	defer engine.fini()
	game.game_setup()
	t, _ := game.create_space_ship({10, 0, 0}, quaternion256(1), true)
	for i in 0 ..< 1000 {
		_, tmp := engine.create_entity(engine.Entity)
		sz := 5
		tmp.phys.position =
			{
				cast(f64)rand.int_range(-sz, sz + 1),
				cast(f64)rand.int_range(-sz, sz + 1),
				cast(f64)rand.int_range(-sz, sz + 1),
			} *
			1
		tmp.phys.rotation = Quat(1)
		tmp.phys.height = 0.5
		tmp.phys.width = 0.5
		tmp.phys.length = 0.5
		tmp.phys.is_static = true
		tmp.mesh.name = engine.string_clone("cube")
		tmp.mesh.diffuse_map_name = engine.string_clone("metal_diffuse.png")
		tmp.mesh.normal_map_name = engine.string_clone("metal_normal.png")
		tmp.mesh.color = raylib.WHITE
	}
	engine.engine_run()
}

test_main :: proc() {
	raylib.InitWindow(1200, 1000, "graphing")
	nd := libgraph.create_graph()
	defer libgraph.destroy_graph(nd)
	{
		for i in 0 ..< 10000 {
			tmp_x := rand.int32_range(0, 1000)
			tmp_y := rand.int32_range(0, 1000)
			pos := Vec3{cast(f64)tmp_x, cast(f64)tmp_y, 0}
			libgraph.create_node(nd, pos)
		}
		for i, idx in nd.nodes {
			for jdx in idx + 1 ..< len(nd.nodes) {
				if linalg.distance(nd.nodes[idx].pos, nd.nodes[jdx].pos) < 50. &&
				   rand.float32() < 0.2 {
					libgraph.connect_nodes(nd, nd.nodes[idx], nd.nodes[jdx])
				}
			}
		}
	}
	path: []^libgraph.Node = nil
	defer delete(path)
	remainder: f32 = 0.
	start_idx := -1
	end_idx := -1
	dur: f64 = 0.
	for !raylib.WindowShouldClose() {
		remainder -= raylib.GetFrameTime()
		if remainder <= 0.0 {
			if path != nil {
				delete(path)
				path = nil
			}
			start := rand.int32_range(0, cast(i32)len(nd.nodes))
			end := rand.int32_range(0, cast(i32)len(nd.nodes))
			if start == end {
				continue
			}
			start_idx = cast(int)start
			end_idx = cast(int)end
			fmt.printf("start_idx:%d, end_idx:%d\n", start_idx, end_idx)
			now := time.now()
			tpath, ok := libgraph.pathfind_nodes(nd, nd.nodes[start], nd.nodes[end])
			dur = time.duration_microseconds(time.since(now))
			fmt.printf("ok:%v\n", ok)
			if ok {
				path = tpath
				remainder = 2.
			} else {
				path = nil
				remainder = 2.
			}
		}
		raylib.BeginDrawing()
		raylib.ClearBackground(raylib.BLACK)
		for i, idx in nd.nodes {
			for j in i.edges {
				if cast(uintptr)j < cast(uintptr)i {
					raylib.DrawLine(
						cast(i32)i.pos.x,
						cast(i32)i.pos.y,
						cast(i32)j.pos.x,
						cast(i32)j.pos.y,
						{40, 0, 0, 255},
					)
				}
			}

		}
		for i, idx in nd.nodes {
			col := raylib.RED
			rad: f32 = 2.
			if idx == start_idx || idx == end_idx {
				col = raylib.GREEN
				rad = 4.
			}
			raylib.DrawCircle(cast(i32)i.pos.x, cast(i32)i.pos.y, rad, col)
		}
		if len(path) > 1 {
			for idx in 0 ..< len(path) - 1 {
				s_x := cast(i32)path[idx].pos.x
				s_y := cast(i32)path[idx].pos.y
				e_x := cast(i32)path[idx + 1].pos.x
				e_y := cast(i32)path[idx + 1].pos.y
				raylib.DrawLine(s_x, s_y, e_x, e_y, raylib.GREEN)
			}
		}
		raylib.DrawFPS(1000, 20)
		raylib.DrawText(
			fmt.ctprintf("time to path:%d microseconds", cast(i32)dur),
			1000,
			50,
			16,
			raylib.BLUE,
		)
		raylib.DrawText(fmt.ctprintf("path length:%d", len(path)), 1000, 100, 16, raylib.BLUE)
		raylib.EndDrawing()
	}
}
