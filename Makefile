c:
	cabal clean

b: c
	cabal build > build.log 2>&1

r: c
	cabal run
