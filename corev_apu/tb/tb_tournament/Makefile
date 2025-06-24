library      ?= work
toplevel     ?= tb
src-list     := tb.list
src          := $(shell xargs printf '\n%s' < $(src-list)  | cut -b 1-)
compile_flag += +cover+/dut -incr -64 -nologo
sim_opts     += -64 -classdebug -voptargs="+acc"
questa_version ?= ${QUESTASIM_VERSION}
incdir       += ../common/
seed = 3

build: clean
	vlib${questa_version} $(library)
	#vlog${questa_version} -work $(library) -pedanticerrors $(src) $(compile_flag) +incdir+$(incdir)
	vlog${questa_version} -work $(library) $(src) $(compile_flag) +incdir+$(incdir)
	touch $(library)/.build

# this starts modelsim with gui
sim: build
	vsim${questa_version} -lib $(library) $(toplevel) -do "do wave.do" $(sim_opts)

# batch mode without gui
simc: build
	vsim${questa_version} -suppress 12110 -novopt -lib $(library) $(toplevel) -c -do "run -all; exit" $(sim_opts) -sv_seed $(seed)

clean:
	rm -rf $(library)

.PHONY: clean simc sim build

