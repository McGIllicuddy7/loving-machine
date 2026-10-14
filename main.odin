package main
import "core:fmt"
import "core:math/linalg"
import "core:math/rand"
import "core:mem"
import "engine"
import "vendor:raylib"
//3,490,216

main :: proc() {
	fmt.printf(
		"sizeof entity:%d, sizeof level:%d\n",
		size_of(engine.Entity),
		size_of(engine.RUNTIME.level),
	)
}
