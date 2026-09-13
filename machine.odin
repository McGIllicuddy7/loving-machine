package main
REGISTER_COUNT: u32 : 4096
Operand :: union {
	i32,
}

InstructionKind :: enum {
	Push,
	Pop,
	Add,
	Sub,
	Mul,
	Div,
	Rem,
	Goto,
	GotoIfZero,
	LoadVar,
	StoreVar,
	LoadPtrVar,
	StorePtrVar,
	CmpE,
	CmpNe,
	CmpG,
	CmpGE,
	CmpLE,
	CmpL,
	And,
	Or,
	Xor,
	Not,
	Call,
	Return,
	SetVar,
	AddConstant,
	SubConstant,
	MulConstant,
	DivConstant,
	RemConstant,
	CmpEConstant,
	CmpNeConstant,
	CmpGConstant,
	CmpGEConstant,
	CmpLEConstant,
	CmpLConstant,
	AndConstant,
	OrConstant,
	XorConstant,
}

Instruction :: struct {
	kind:     InstructionKind,
	data:     Operand,
	constant: i32,
}

Machine :: struct {
	halted:                  bool,
	ip:                      u32,
	instructions:            []Instruction,
	stack:                   [dynamic]Operand,
	return_stack:            [dynamic]u32,
	variables:               [REGISTER_COUNT]Operand,
	previous_variable_stack: [dynamic][REGISTER_COUNT]Operand,
	symbol_table:            map[u32]string,
}

machine_step :: proc(this: ^Machine) -> bool {
	if this.ip >= cast(u32)len(this.instructions) {
		this.halted = true
		return false
	}
	ins := this.instructions[this.ip]
	switch ins.kind {
	case InstructionKind.Push:
		append_elem(&this.stack, ins.data)
		break
	case InstructionKind.Pop:
		_ = machine_stack_pop(this) or_return
		break
	case InstructionKind.Add:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) + right.(i32))
		break
	case InstructionKind.Sub:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) - right.(i32))
		break
	case InstructionKind.Mul:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) * right.(i32))
		break
	case InstructionKind.Div:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) / right.(i32))
		break
	case InstructionKind.Rem:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) % right.(i32))
		break
	case InstructionKind.Goto:
		this.ip = cast(u32)ins.data.(i32)
		break
	case InstructionKind.GotoIfZero:
		ip := cast(u32)ins.data.(i32)
		op := machine_stack_pop(this) or_return
		if (op.(i32) == 0) {
			this.ip = ip
		}
		break
	case InstructionKind.LoadVar:
		var := this.variables[ins.data.(i32)]
		machine_stack_push(this, var)
		break
	case InstructionKind.StoreVar:
		this.variables[ins.data.(i32)] = machine_stack_pop(this) or_return
		break
	case InstructionKind.LoadPtrVar:
		ptr := machine_stack_pop(this) or_return
		machine_stack_push(this, this.variables[ptr.(i32)])
		break
	case InstructionKind.StorePtrVar:
		ptr := machine_stack_pop(this) or_return
		var := machine_stack_pop(this) or_return
		this.variables[ptr.(i32)] = var
		break
	case InstructionKind.CmpE:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) == right.(i32)) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpNe:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) != right.(i32)) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpG:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) > right.(i32)) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpGE:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) >= right.(i32)) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpLE:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) <= right.(i32)) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpL:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) < right.(i32)) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.And:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) & right.(i32))
		machine_stack_push(this, x)
		break
	case InstructionKind.Or:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) | right.(i32))
		machine_stack_push(this, x)
		break
	case InstructionKind.Xor:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) ~ right.(i32))
		machine_stack_push(this, x)
		break
	case InstructionKind.Not:
		var := machine_stack_pop(this) or_return
		x: Operand = ~var.(i32)
		machine_stack_push(this, x)
		break
	case InstructionKind.Call:
		append_elem(&this.previous_variable_stack, this.variables)
		append_elem(&this.return_stack, this.ip)
		this.ip = cast(u32)ins.data.(i32)
		break
	case InstructionKind.Return:
		if len(this.return_stack) == 0 {
			this.halted = true
		} else {
			this.variables = this.previous_variable_stack[len(this.previous_variable_stack) - 1]
			pop(&this.previous_variable_stack)
			this.ip = this.return_stack[len(this.return_stack) - 1]
			pop(&this.return_stack)
		}
		break
	case InstructionKind.AddConstant:
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) + ins.constant)
		break
	case InstructionKind.SubConstant:
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) - ins.constant)
		break
	case InstructionKind.MulConstant:
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) * ins.constant)
		break
	case InstructionKind.DivConstant:
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) / ins.constant)
		break
	case InstructionKind.RemConstant:
		left := machine_stack_pop(this) or_return
		machine_stack_push(this, left.(i32) % ins.constant)
		break
	case InstructionKind.CmpEConstant:
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) == ins.constant) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpNeConstant:
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) != ins.constant) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpGConstant:
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) > ins.constant) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpGEConstant:
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) >= ins.constant) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpLEConstant:
		right := machine_stack_pop(this) or_return
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) <= right.(i32)) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.CmpLConstant:
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) < ins.constant) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.AndConstant:
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32)& ins.constant) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.OrConstant:
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) |  ins.constant) ? 1 : 0
		machine_stack_push(this, x)
		break
	case InstructionKind.XorConstant:
		left := machine_stack_pop(this) or_return
		x: Operand = (left.(i32) ~ ins.constant) ? 1 : 0
		machine_stack_push(this, x)
		break

	this.ip += 1
	return !this.halted
}


machine_stack_pop :: proc(this: ^Machine) -> (Operand, bool) {
	if (len(this.stack) > 0) {
		out := this.stack[len(this.stack)]
		pop(&this.stack)
		return out, true
	}
	this.halted = true
	return nil, false
}

machine_stack_push :: proc(this: ^Machine, op: Operand) {
	append_elem(&this.stack, op)
}
