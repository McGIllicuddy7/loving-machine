
package main
import "core:fmt"
_ :: fmt
main :: proc() {
	setup_runtime()
	gen_map_debug()
	defer teardown_runtime()
	for (!rl.WindowShouldClose()) {
		runtime_step()
	}
}
