# Note: Last tested with version 1.38.15 of Emscripten

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
EMFLAGS = \
	--memory-init-file 0 \
	-s RESERVED_FUNCTION_POINTERS=64 \
	-s EXPORTED_FUNCTIONS=@exported_functions \
	-s EXTRA_EXPORTED_RUNTIME_METHODS=@exported_runtime_methods \
	-s SINGLE_FILE=0 \
	-s ENVIRONMENT=node

EMFLAGS_WASM = \
	-s WASM=1 \
	-s ALLOW_MEMORY_GROWTH=1 

EMFLAGS_OPTIMIZED= \
	-Oz \
	--closure 1

EMFLAGS_DEBUG = \
	-s INLINING_LIMIT=10 \
	-O1

BITCODE_FILES = c/sqlite3.bc c/extension-functions.bc
OUTPUT_WRAPPER_FILES = js/shell-pre.js js/shell-post.js

all: optimized debug worker

.PHONY: debug
debug: js/sql-debug.js js/sql-wasm-debug.js

js/sql-debug.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) js/api.js exported_functions exported_runtime_methods 
	$(EMCC) $(EMFLAGS) $(EMFLAGS_DEBUG) -s WASM=0 $(BITCODE_FILES) --pre-js js/api.js -o $@
	mv $@ js/tmp-raw.js
	cat js/shell-pre.js js/tmp-raw.js js/shell-post.js > $@
	rm js/tmp-raw.js

js/sql-wasm-debug.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) js/api.js exported_functions exported_runtime_methods 
	$(EMCC) $(EMFLAGS) $(EMFLAGS_DEBUG) $(EMFLAGS_WASM) $(BITCODE_FILES) --pre-js js/api.js -o $@
	mv $@ js/tmp-raw.js
	cat js/shell-pre.js js/tmp-raw.js js/shell-post.js > $@
	rm js/tmp-raw.js


.PHONY: optimized
optimized: js/sql.js js/sql-wasm.js js/sql-memory-growth.js

js/sql.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) js/api.js exported_functions exported_runtime_methods 
	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) -s WASM=0 $(BITCODE_FILES) --pre-js js/api.js -o $@
	mv $@ js/tmp-raw.js
	cat js/shell-pre.js js/tmp-raw.js js/shell-post.js > $@
	rm js/tmp-raw.js

js/sql-wasm.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) js/api.js exported_functions exported_runtime_methods 
	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) $(EMFLAGS_WASM) $(BITCODE_FILES) --pre-js js/api.js -o $@
	mv $@ js/tmp-raw.js
	cat js/shell-pre.js js/tmp-raw.js js/shell-post.js > $@
	rm js/tmp-raw.js

js/sql-memory-growth.js: $(BITCODE_FILES) $(OUTPUT_WRAPPER_FILES) js/api.js exported_functions exported_runtime_methods 
	$(EMCC) $(EMFLAGS) $(EMFLAGS_OPTIMIZED) -s WASM=0 -s ALLOW_MEMORY_GROWTH=1 $(BITCODE_FILES) --pre-js js/api.js -o $@
	mv $@ js/tmp-raw.js
	cat js/shell-pre.js js/tmp-raw.js js/shell-post.js > $@
	rm js/tmp-raw.js


# Web worker API
.PHONY: worker
worker: js/worker.sql.js js/worker.sql-debug.js js/worker.sql-wasm.js js/worker.sql-wasm-debug.js

js/worker.js: coffee/worker.coffee
	cat $^ | coffee --bare --compile --stdio > $@

js/worker.sql.js: js/sql.js js/worker.js
	cat $^ > $@

js/worker.sql-debug.js: js/sql-debug.js js/worker.js
	cat $^ > $@

js/worker.sql-wasm.js: js/sql-wasm.js js/worker.js
	cat $^ > $@

js/worker.sql-wasm-debug.js: js/sql-wasm-debug.js js/worker.js
	cat $^ > $@

js/api.js: coffee/output-pre.js coffee/api.coffee coffee/exports.coffee coffee/api-data.coffee coffee/output-post.js
	cat coffee/api.coffee coffee/exports.coffee coffee/api-data.coffee | coffee --bare --compile --stdio > $@
	cat coffee/output-pre.js $@ coffee/output-post.js > js/api-wrapped.js
	mv js/api-wrapped.js $@

c/sqlite3.bc: c/sqlite3.c
	# Generate llvm bitcode
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) c/sqlite3.c -o c/sqlite3.bc

c/extension-functions.bc: c/extension-functions.c
	$(EMCC) $(SQLITE_COMPILATION_FLAGS) -s LINKABLE=1 c/extension-functions.c -o c/extension-functions.bc

module.tar.gz: test package.json AUTHORS README.md js/sql.js
	tar --create --gzip $^ > $@

.PHONY: clean
clean:
	rm -rf \
	js/api.js \
	js/sql*.js \
	js/sql*.wasm \
	c/sqlite3.bc c/extension-functions.bc


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
