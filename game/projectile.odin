package game
Bullet :: struct {
	using _parent:      Entity,
	remaining_lifetime: f64,
}

Missile :: struct {
	using _parent:      Entity,
	remaining_lifetime: f64,
	target:             EntityRef,
}

create_bullet :: proc() {}
