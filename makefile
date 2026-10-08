make: .
	odin build . -out:a.out -sanitize:address -debug

run: .
	make 
	./a.out