clean:
	cabal clean
build: clean
	cabal build > build.log 2>&1
