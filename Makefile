# Note: Last built with version 1.38.30 of Emscripten

# TODO: Emit a file showing which version of emcc and SQLite was used to compile the emitted output.
# TODO: Create a release on Github with these compiled assets rather than checking them in
# TODO: Consider creating different files based on browser vs module usage: https://github.com/vuejs/vue/tree/dev/dist

# I got this handy makefile syntax from : https://github.com/mandel59/sqlite-wasm (MIT License) Credited in LICENSE
# To use another version of Sqlite, visit https://www.sqlite.org/download.html and copy the appropriate values here:
SQLITE_AMALGAMATION = sqlite-amalgamation-3280000
SQLITE_AMALGAMATION_ZIP_URL = https://www.sqlite.org/2019/sqlite-amalgamation-3280000.zip
SQLITE_AMALGAMATION_ZIP_SHA1 = eb82fcc95104c8e2d9550ab023c1054b9cc40a76

# Note that extension-functions.c hasn't been updated since 2010-02-06, so likely doesn't need to be updated 
EXTENSION_FUNCTIONS = extension-functions.c
EXTENSION_FUNCTIONS_URL = https://www.sqlite.org/contrib/download/extension-functions.c?get=25
EXTENSION_FUNCTIONS_SHA1 = c68fa706d6d9ff98608044c00212473f9c14892f

EMCC=emcc

SQLITE_COMPILATION_FLAGS= \
	-DSQLITE_OMIT_LOAD_EXTENSION \
	-DSQLITE_DISABLE_LFS \
	-DLONGDOUBLE_TYPE=double \
	-DSQLITE_ENABLE_FTS3 \
	-DSQLITE_ENABLE_FTS3_PARENTHESIS \
	-DSQLITE_THREADSAFE=0 \
	-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1 \
	-DSQLITE_LIKE_DOESNT_MATCH_BLOBS \
	-DSQLITE_MAX_EXPR_DEPTH=0 \
	-DSQLITE_OMIT_DECLTYPE \
	-DSQLITE_OMIT_DEPRECATED \
	-DSQLITE_OMIT_PROGRESS_CALLBACK \
	-DSQLITE_OMIT_SHARED_CACHE \
	-DSQLITE_USE_ALLOCA \
	-DSQLITE_DEFAULT_MEMSTATUS=0 \
	-DSQLITE_BYTEORDER=1234 \
	-DSQLITE_HAVE_ISNAN=1 \
	-DHAVE_MALLOC_USABLE_SIZE=1 \
	-DHAVE_STRCHRNUL=1 \
	-DSQLITE_TEMP_STORE=2 \
	-DSQLITE_THREADSAFE=0 \
	-DSQLITE_USE_URI=1 \
	-Oz

	# For the smallest filesize, leave JSON disabled
	#-DSQLITE_ENABLE_JSON1=0 \

# When compiling to WASM, enabling memory-growth is not expected to make much of an impact, so we enable it for all builds
# Since tihs is a library and not a standalone executable, we don't want to catch unhandled Node process exceptions
# So, we do : `NODEJS_CATCH_EXIT=0`, which fixes issue: https://github.com/kripken/sql.js/issues/173 and https://github.com/kripken/sql.js/issues/262
EMFLAGS = \
	--memory-init-file 0 \
	-s RESERVED_FUNCTION_POINTERS=64 \
	-s EXPORTED_FUNCTIONS=@src/exported_functions.json \
	-s EXTRA_EXPORTED_RUNTIME_METHODS=@src/exported_runtime_methods.json \
	-s SINGLE_FILE=0 \
	-s NODEJS_CATCH_EXIT=0

EMFLAGS_WASM = \
	-s WASM=1 \
	-s ALLOW_MEMORY_GROWTH=1 

EMFLAGS_OPTIMIZED= \
	-Oz \
	--closure 1

EMFLAGS_DEBUG = \
	-s INLINING_LIMIT=10 \
	-O1

BITCODE_FILES = out/sqlite3.bc out/extension-functions.bc
OUTPUT_WRAPPER_FILES = src/shell-pre.js src/shell-post.js

all: optimized debug worker

.PHONY: debug
debug: dist/sql-asm-debug.js dist/sql-wasm-debug.js

dist/sql-asm-debug.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) out/api.js src/exported_functions.json src/exported_runtime_methods.json
	$(EMCC) $(EMFLAGS) $(EMFLAGS_DEBUG) -s WASM=0 $(BITCODE_FILES) --pre-js out/api.js -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js

dist/sql-wasm-debug.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) out/api.js src/exported_functions.json src/exported_runtime_methods.json
	$(EMCC) $(EMFLAGS) $(EMFLAGS_DEBUG) $(EMFLAGS_WASM) $(BITCODE_FILES) --pre-js out/api.js -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js

.PHONY: optimized
optimized: dist/sql-asm.js dist/sql-wasm.js dist/sql-asm-memory-growth.js

dist/sql-asm.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) out/api.js src/exported_functions.json src/exported_runtime_methods.json 
	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) -s WASM=0 $(BITCODE_FILES) --pre-js out/api.js -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js

dist/sql-wasm.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) out/api.js src/exported_functions.json src/exported_runtime_methods.json 
	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) $(EMFLAGS_WASM) $(BITCODE_FILES) --pre-js out/api.js -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js

dist/sql-asm-memory-growth.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) out/api.js src/exported_functions.json src/exported_runtime_methods.json 
	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) -s WASM=0 -s ALLOW_MEMORY_GROWTH=1 $(BITCODE_FILES) --pre-js out/api.js -o $@
	mv $@ out/tmp-raw.js
	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js > $@
	rm out/tmp-raw.js


# Web worker API
.PHONY: worker
worker: dist/worker.sql-asm.js dist/worker.sql-asm-debug.js dist/worker.sql-wasm.js dist/worker.sql-wasm-debug.js

out/worker.js: src/worker.coffee
	cat $^ | coffee --bare --compile --stdio > $@

dist/worker.sql-asm.js: dist/sql-asm.js out/worker.js
	cat $^ > $@

dist/worker.sql-asm-debug.js: dist/sql-asm-debug.js out/worker.js
	cat $^ > $@

dist/worker.sql-wasm.js: dist/sql-wasm.js out/worker.js
	cat $^ > $@

dist/worker.sql-wasm-debug.js: dist/sql-wasm-debug.js out/worker.js
	cat $^ > $@

# Building it this way gets us a wrapper that _knows_ it's in worker mode, which is nice.
# However, since we can't tell emcc that we don't need the wasm generated, and just want the wrapper, we have to pay to have the .wasm generated
# even though we would have already generated it with our sql-wasm.js target above.
# This would be made easier if this is implemented: https://github.com/emscripten-core/emscripten/issues/8506
# dist/worker.sql-wasm.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) out/api.js out/worker.js src/exported_functions.json src/exported_runtime_methods.json dist/sql-wasm-debug.wasm
# 	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) -s ENVIRONMENT=worker -s $(EMFLAGS_WASM) $(BITCODE_FILES) --pre-js out/api.js -o out/sql-wasm.js
# 	mv out/sql-wasm.js out/tmp-raw.js
# 	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js out/worker.js > $@
# 	#mv out/sql-wasm.wasm dist/sql-wasm.wasm
# 	rm out/tmp-raw.js

# dist/worker.sql-wasm-debug.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) out/api.js out/worker.js src/exported_functions.json src/exported_runtime_methods.json dist/sql-wasm-debug.wasm
# 	$(EMCC) -s ENVIRONMENT=worker $(EMFLAGS) $(EMFLAGS_DEBUG) -s ENVIRONMENT=worker -s WASM_BINARY_FILE=sql-wasm-foo.debug $(EMFLAGS_WASM) $(BITCODE_FILES) --pre-js out/api.js -o out/sql-wasm-debug.js
# 	mv out/sql-wasm-debug.js out/tmp-raw.js
# 	cat src/shell-pre.js out/tmp-raw.js src/shell-post.js out/worker.js > $@
# 	#mv out/sql-wasm-debug.wasm dist/sql-wasm-debug.wasm
# 	rm out/tmp-raw.js

out/api.js: src/output-pre.js src/api.coffee src/exports.coffee src/api-data.coffee src/output-post.js
	cat src/api.coffee src/exports.coffee src/api-data.coffee | coffee --bare --compile --stdio > $@
	cat src/output-pre.js $@ src/output-post.js > out/api-wrapped.js
	mv out/api-wrapped.js $@

out/sqlite3.bc: sqlite-src/$(SQLITE_AMALGAMATION)
	# Generate llvm bitcode
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) sqlite-src/$(SQLITE_AMALGAMATION)/sqlite3.c -o $@

out/extension-functions.bc: sqlite-src/$(SQLITE_AMALGAMATION)/$(EXTENSION_FUNCTIONS)
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) -s LINKABLE=1 sqlite-src/$(SQLITE_AMALGAMATION)/extension-functions.c -o $@

# TODO: This target appears to be unused. If we re-instatate it, we'll need to add more files inside of the JS folder
# module.tar.gz: test package.json AUTHORS README.md dist/sql-asm.js
# 	tar --create --gzip $^ > $@

## cache

.PHONY: clean-cache
clean-cache:
	rm -rf cache

cache/$(SQLITE_AMALGAMATION).zip:
	mkdir -p cache
	curl -LsSf '$(SQLITE_AMALGAMATION_ZIP_URL)' -o $@

cache/$(EXTENSION_FUNCTIONS):
	mkdir -p cache
	curl -LsSf '$(EXTENSION_FUNCTIONS_URL)' -o $@

## sqlite-src

.PHONY: clean-sqlite-src
clean-sqlite-src:
	rm -rf sqlite

.PHONY: sqlite-src
sqlite-src: sqlite-src/$(SQLITE_AMALGAMATION) sqlite-src/$(EXTENSION_FUNCTIONS)

sqlite-src/$(SQLITE_AMALGAMATION): cache/$(SQLITE_AMALGAMATION).zip
	mkdir -p sqlite-src
	echo '$(SQLITE_AMALGAMATION_ZIP_SHA1)  ./cache/$(SQLITE_AMALGAMATION).zip' > cache/check.txt
	sha1sum -c cache/check.txt
	rm -rf $@
	unzip 'cache/$(SQLITE_AMALGAMATION).zip' -d sqlite-src/
	touch $@

sqlite-src/$(SQLITE_AMALGAMATION)/$(EXTENSION_FUNCTIONS): cache/$(EXTENSION_FUNCTIONS)
	mkdir -p sqlite-src
	echo '$(EXTENSION_FUNCTIONS_SHA1)  ./cache/$(EXTENSION_FUNCTIONS)' > cache/check.txt
	sha1sum -c cache/check.txt
	cp 'cache/$(EXTENSION_FUNCTIONS)' $@


.PHONY: clean 
clean: 
	rm -rf out/* dist/*	

.PHONY: clean-all
clean-all: 
	rm -f out/* dist/* cache/*
	rm -rf sqlite-src/

# Notes about file sizes:
# 
# Sizes of optimized .wasm based on these compilation flags:
# SQLITE_COMPILATION_FLAGS= \
# 	-DSQLITE_OMIT_LOAD_EXTENSION \
# 	-DSQLITE_DISABLE_LFS \
# 	-DLONGDOUBLE_TYPE=double \
# 	-DSQLITE_ENABLE_FTS3 \
# 	-DSQLITE_ENABLE_FTS3_PARENTHESIS \
# 	-DSQLITE_THREADSAFE=0 \
# 	-DSQLITE_DEFAULT_WAL_SYNCHRONOUS=1 \
# 	-DSQLITE_LIKE_DOESNT_MATCH_BLOBS \
# 	-DSQLITE_MAX_EXPR_DEPTH=0 \
# 	-DSQLITE_OMIT_DECLTYPE \
# 	-DSQLITE_OMIT_DEPRECATED \
# 	-DSQLITE_OMIT_PROGRESS_CALLBACK \
# 	-DSQLITE_OMIT_SHARED_CACHE \
# 	-DSQLITE_USE_ALLOCA \

# No opt settings on either .bc or .js compilation:
# .bc: 1.8MB, sql.js: 7.5MB, sql.wasm: 1.5MB
# $ node test/test_perf.js
# Loaded and inited ../js/sql.js in 278ms
# Started benchmark function...
# Total time to execute benchmark func:  5073 ms
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 166ms
# Started benchmark function...
# Total time to execute benchmark func:  1177 ms

# No settings on c comp, but -0z on js output:
# .bc: 1.8MB, sql.js: 2.1MB, sql.wasm: 925KB
# ASM.js:
# $ node test/test_perf.js
# Loaded and inited ../js/sql.js in 253ms
# Started benchmark function...
# Total time to execute benchmark func:  1424 ms
# WASM
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 537ms
# Started benchmark function...
# Total time to execute benchmark func:  615 ms

# -Oz on c comp, nothing on js output:
# .bc 1.6, sql.js: 5.2, sql.wasm: 1MB
#ASM.js:
#$ node test/test_perf.js
# Loaded and inited ../js/sql.js in 198ms
# Started benchmark function...
# Total time to execute benchmark func:  4046 ms
#WASM:
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 126ms
# Started benchmark function...
# Total time to execute benchmark func:  1072 ms


# -Oz, -0z: .bc 1.6MB, sql.js: 1.2, .wasm: 571KB
# ASM.js:
# $ node test/test_perf.js
# Loaded and inited ../js/sql.js in 164ms
# Started benchmark function...
# Total time to execute benchmark func:  976 ms
# WASM
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 436ms
# Started benchmark function...
# Total time to execute benchmark func:  513 ms

# -Oz, -03: .bc 1.6MB, sql.js: 1.2, .wasm: 593KB - 535ms - 
# ASM.js:
# $ node test/test_perf.js
# Loaded and inited ../js/sql.js in 166ms
# Started benchmark function...
# Total time to execute benchmark func:  948 ms
# WASM
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 438ms
# Started benchmark function...
# Total time to execute benchmark func:  490 ms


# -O3, -O3: .bc: 4.0MB, sql.js 2.9MB, .wasm: 1.4MB 
# ASM.js:
# $ node test/test_perf.js
# Loaded and inited ../js/sql.js in 333ms
# Started benchmark function...
# Total time to execute benchmark func:  3407 ms
# WASM
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 832ms
# Started benchmark function...
# Total time to execute benchmark func:  499 ms


# -O3, -Oz: .bc: 1.6MB, sql.js 2.9MB, .wasm: 1.4MB
# ASM.js:
# $ node test/test_perf.js
# Loaded and inited ../js/sql.js in 324ms
# Started benchmark function...
# Total time to execute benchmark func:  3379 ms
# WASM:
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 844ms
# Started benchmark function...
# Total time to execute benchmark func:  497 ms

# -Os, -Os
#1.7MB 1.4MB 583k
# ASM.js: 
# $ node test/test_perf.js
# Loaded and inited ../js/sql.js in 169ms
# Started benchmark function...
# Total time to execute benchmark func:  973 ms
# WASM
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 467ms
# Started benchmark function...
# Total time to execute benchmark func:  505 ms


# Sizes now after adding these settings:
# -DSQLITE_BYTEORDER=1234 \
# 	-DSQLITE_ENABLE_JSON1=1 \
# 	-DSQLITE_HAVE_ISNAN=1 \
# 	-DHAVE_MALLOC_USABLE_SIZE=1 \
# 	-DHAVE_STRCHRNUL=1 \
# 	-DSQLITE_TEMP_STORE=2 \
# 	-DSQLITE_THREADSAFE=0 \
# 	-DSQLITE_USE_URI=1 \
#
# -Oz -Oz:
# .bc:1.7MB sql.js:1.3 sql.wasm:599
#ASM.js:
# $ node test/test_perf.js
# Loaded and inited ../js/sql.js in 171ms
# Started benchmark function...
# Total time to execute benchmark func:  943 ms
#WASM:
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 451ms
# Started benchmark function...
# Total time to execute benchmark func:  516 ms
# WASM - single-file: - sql-wasm.js: 843kb
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 461ms
# Started benchmark function...
# Total time to execute benchmark func:  514 ms

# Taking out the JSON stuff:
# -Oz -Oz .bc: 1.6 sql.js: 1.2 sql.wasm: 571KB
# asm.js:
# $ node test/test_perf.js
# Loaded and inited ../js/sql.js in 154ms
# Started benchmark function...
# Total time to execute benchmark func:  933 ms
# WASM
# $ node test/test_perf.js wasm
# Loaded and inited ../js/sql-wasm.js in 438ms
# Started benchmark function...
# Total time to execute benchmark func:  490 ms

# Conclusion: 
# Use -Oz -Oz for a very small, fast build. However, although the runtime is fast, the file takes 500ms to load on the same machine that only takes 154ms to load the asm.js build

