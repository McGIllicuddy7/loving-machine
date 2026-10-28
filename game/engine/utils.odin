package engine

import "core:math"
import "core:math/rand"

random_vec3 :: proc() -> Vec3 {
	r := rand.float64()
	theta := rand.float64_range(0, 2 * math.PI)
	phi := rand.float64_range(0, 2 * math.PI)
	return(
		Vec3{math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(phi)} *
		r \
	)
}

random_vec3f :: proc() -> Vec3f {
	r := rand.float32()
	theta := rand.float32_range(0, 2 * math.PI)
	phi := rand.float32_range(0, 2 * math.PI)
	return(
		Vec3f{math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(phi)} *
		r \
	)
}

random_vec3_n :: proc() -> Vec3 {
	r := 1.
	theta := rand.float64_range(0, 2 * math.PI)
	phi := rand.float64_range(0, 2 * math.PI)
	return(
		Vec3{math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(phi)} *
		r \
	)
}

random_vec3f_n :: proc() -> Vec3f {
	r: f32 = 1.
	theta := rand.float32_range(0, 2 * math.PI)
	phi := rand.float32_range(0, 2 * math.PI)
	return(
		Vec3f{math.cos(theta) * math.sin(phi), math.sin(theta) * math.sin(phi), math.cos(phi)} *
		r \
	)
}
