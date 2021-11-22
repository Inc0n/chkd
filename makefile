NIMCC=arch -arm64 nimble

all:
	cd c/ && make
	make updatenim

clean:
	cd c/ && make clean

# sometimes we need to update nim, tho rare but required
updatenim:
	$(NIMCC) build -d:debug --verbose --app:console --passL:c/build/libckhd.so

run: updatenim
	./main

test: updatenim
	./main --verbose -p -c:./tests/test.conf