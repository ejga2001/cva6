VIVADO ?= vivado
VIVADOFLAGS ?= -nojournal -mode batch -source scripts/prologue.tcl

work-dir := work-fpga
bit := $(work-dir)/ariane_xilinx.bit
mcs := $(work-dir)/ariane_xilinx.mcs
ip-dir := xilinx
ips := xlnx_axi_clock_converter.xci  \
       xlnx_axi_dwidth_converter.xci \
       xlnx_axi_dwidth_converter_dm_master.xci \
       xlnx_axi_dwidth_converter_dm_slave.xci \
       xlnx_axi_quad_spi.xci         \
       xlnx_axi_gpio.xci             \
       xlnx_clk_gen.xci              \
       xlnx_mig_7_ddr3.xci

ips := $(addprefix $(work-dir)/, $(ips))
ips-target := $(join $(addsuffix /ip/, $(addprefix $(ip-dir)/, $(basename $(ips)))), $(ips))

BRANCH_PRED_IMPL := 3
BHT_ENTRIES := 1024
MBP_ENTRIES := 1024
GBP_ENTRIES := 1024
LBP_ENTRIES := 1024
LHR_ENTRIES := 1024
BHT_CTR_BITS := 2
CHOICE_CTR_BITS := 2
GLOBAL_CTR_BITS := 2
LOCAL_CTR_BITS := 2

all: $(ips) $(bit)

ips_rule: $(ips)

bit_bht:
	mkdir -p $(work-dir)
	$(VIVADO) $(VIVADOFLAGS) -source scripts/run_bht.tcl -tclargs $(BHT_ENTRIES) $(BHT_CTR_BITS)
	cp ariane.runs/impl_1/ariane_xilinx* ./$(work-dir)

bit_gbp:
	mkdir -p $(work-dir)
	$(VIVADO) $(VIVADOFLAGS) -source scripts/run_gbp.tcl -tclargs $(GBP_ENTRIES) $(GLOBAL_CTR_BITS)
	cp ariane.runs/impl_1/ariane_xilinx* ./$(work-dir)

bit_lbp:
	mkdir -p $(work-dir)
	$(VIVADO) $(VIVADOFLAGS) -source scripts/run_lbp.tcl -tclargs $(LBP_ENTRIES) $(LHR_ENTRIES) $(LOCAL_CTR_BITS)
	cp ariane.runs/impl_1/ariane_xilinx* ./$(work-dir)

bit_tournament:
	mkdir -p $(work-dir)
	$(VIVADO) $(VIVADOFLAGS) -source scripts/run_tournament.tcl -tclargs $(MBP_ENTRIES) $(GBP_ENTRIES) $(LBP_ENTRIES) $(LHR_ENTRIES) $(CHOICE_CTR_BITS) $(GLOBA_CTR_BITS) $(LOCAL_CTR_BITS)
	cp ariane.runs/impl_1/ariane_xilinx* ./$(work-dir)

# Generate mcs from bitstream
$(mcs): $(bit)
	$(VIVADO) $(VIVADOFLAGS) -source scripts/write_cfgmem.tcl -tclargs $@ $^

$(bit):
	mkdir -p $(work-dir)
	$(VIVADO) $(VIVADOFLAGS) -source scripts/run.tcl -tclargs $(BRANCH_PRED_IMPL) $(BHT_ENTRIES) $(BHT_CTR_BITS)
	cp ariane.runs/impl_1/ariane_xilinx* ./$(work-dir)

$(ips): %.xci :
	mkdir -p $(work-dir)
	@echo Generating $(@F)
	@cd $(ip-dir)/$(basename $(@F)) && make clean && make
	@cp $(ip-dir)/$(basename $(@F))/$(basename $(@F)).srcs/sources_1/ip/$(basename $(@F))/$(@F) $@

mcs: $(mcs)

program:
	$(VIVADO) $(VIVADOFLAGS) -source scripts/program.tcl

clean:
	rm -rf *.log *.jou *.str *.mif *.xpr $(work-dir) bitstreams xilinx_projects ariane.cache ariane.hw ariane.ip_user_files scripts/vivado*

.PHONY:
	clean
