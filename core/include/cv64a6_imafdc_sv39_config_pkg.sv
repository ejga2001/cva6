// Copyright 2021 Thales DIS design services SAS
//
// Licensed under the Solderpad Hardware Licence, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.0
// You may obtain a copy of the License at https://solderpad.org/licenses/
//
// Original Author: Jean-Roch COULON - Thales

`ifndef BRANCH_PRED_IMPL
  `define BRANCH_PRED_IMPL 0
`endif

`ifndef BHT_ENTRIES
  `define BHT_ENTRIES 1024
`endif

`ifndef MBP_ENTRIES
  `define MBP_ENTRIES 1024
`endif

`ifndef GBP_ENTRIES
  `define GBP_ENTRIES 1024
`endif

`ifndef LBP_ENTRIES
  `define LBP_ENTRIES 1024
`endif

`ifndef LHR_ENTRIES
  `define LHR_ENTRIES 1024
`endif

`ifndef BHT_CTR_BITS
 `define BHT_CTR_BITS 2
`endif

`ifndef CHOICE_CTR_BITS
  `define CHOICE_CTR_BITS 2
`endif

`ifndef GLOBAL_CTR_BITS
  `define GLOBAL_CTR_BITS 2
`endif

`ifndef LOCAL_CTR_BITS
  `define LOCAL_CTR_BITS 2
`endif

// TAGE predictor

`ifndef POWER
    `define POWER 1
`endif

`ifndef N_HISTORY_TABLES
    `define N_HISTORY_TABLES 6
`endif

`ifndef HIST_LENGTHS
    `define HIST_LENGTHS {32'd2, 32'd4, 32'd8, 32'd16, 32'd32, 32'd64}
`endif

`ifndef TAG_TABLE_TAG_WIDTHS
    `define TAG_TABLE_TAG_WIDTHS {32'd7, 32'd7, 32'd8, 32'd8, 32'd9, 32'd9}
`endif

`ifndef TAG_TABLE_SIZES
    `define TAG_TABLE_SIZES {32'd256, 32'd256, 32'd256, 32'd512, 32'd512, 32'd512}
`endif

`ifndef TAG_TABLE_COUNTER_BITS
    `define TAG_TABLE_COUNTER_BITS 3
`endif

`ifndef TAG_TABLE_UBITS
    `define TAG_TABLE_UBITS 2
`endif

`ifndef HIST_BUFFER_BITS
    `define HIST_BUFFER_BITS 256
`endif

`ifndef PATH_HIST_BITS
    `define PATH_HIST_BITS 16
`endif

`ifndef U_RESET_PERIOD
    `define U_RESET_PERIOD 2048   // 2^11
`endif

`ifndef NUM_USE_ALT_ON_NA
    `define NUM_USE_ALT_ON_NA 1
`endif

`ifndef INITIAL_RST_CTR_VALUE
    `define INITIAL_RST_CTR_VALUE 1024   // 2^10
`endif

`ifndef USE_ALT_ON_NA_BITS
    `define USE_ALT_ON_NA_BITS 4
`endif

package cva6_config_pkg;
  localparam CVA6ConfigXlen = 64;

  localparam CVA6ConfigRVF = 1;
  localparam CVA6ConfigF16En = 0;
  localparam CVA6ConfigF16AltEn = 0;
  localparam CVA6ConfigF8En = 0;
  localparam CVA6ConfigFVecEn = 0;

  localparam CVA6ConfigCvxifEn = 1;
  localparam CVA6ConfigCExtEn = 1;
  localparam CVA6ConfigZcbExtEn = 1;
  localparam CVA6ConfigZcmpExtEn = 0;
  localparam CVA6ConfigAExtEn = 1;
  localparam CVA6ConfigHExtEn = 0;  // always disabled
  localparam CVA6ConfigBExtEn = 1;
  localparam CVA6ConfigVExtEn = 0;
  localparam CVA6ConfigRVZiCond = 1;

  localparam CVA6ConfigAxiIdWidth = 4;
  localparam CVA6ConfigAxiAddrWidth = 64;
  localparam CVA6ConfigAxiDataWidth = 64;
  localparam CVA6ConfigFetchUserEn = 0;
  localparam CVA6ConfigFetchUserWidth = CVA6ConfigXlen;
  localparam CVA6ConfigDataUserEn = 0;
  localparam CVA6ConfigDataUserWidth = CVA6ConfigXlen;

  localparam CVA6ConfigIcacheByteSize = 16384;
  localparam CVA6ConfigIcacheSetAssoc = 4;
  localparam CVA6ConfigIcacheLineWidth = 128;
  localparam CVA6ConfigDcacheByteSize = 32768;
  localparam CVA6ConfigDcacheSetAssoc = 8;
  localparam CVA6ConfigDcacheLineWidth = 128;

  localparam CVA6ConfigDcacheIdWidth = 1;
  localparam CVA6ConfigMemTidWidth = 2;

  localparam CVA6ConfigWtDcacheWbufDepth = 8;

  localparam CVA6ConfigNrScoreboardEntries = 8;

  localparam CVA6ConfigNrLoadPipeRegs = 1;
  localparam CVA6ConfigNrStorePipeRegs = 0;
  localparam CVA6ConfigNrLoadBufEntries = 2;

  localparam CVA6ConfigRASDepth = 2;
  localparam CVA6ConfigBTBEntries = 32;

  localparam CVA6ConfigBranchPredictorImpl = `BRANCH_PRED_IMPL;
  localparam CVA6ConfigBHTEntries = `BHT_ENTRIES;
  localparam CVA6ConfigChoicePredictorSize = `MBP_ENTRIES;
  localparam CVA6ConfigGlobalPredictorSize = `GBP_ENTRIES;
  localparam CVA6ConfigLocalPredictorSize = `LBP_ENTRIES;
  localparam CVA6ConfigLocalHistoryTableSize = `LHR_ENTRIES;
  localparam CVA6ConfigBHTIndexBits = $clog2(`BHT_ENTRIES);
  localparam CVA6ConfigChoicePredictorIndexBits = $clog2(`MBP_ENTRIES);
  localparam CVA6ConfigGlobalPredictorIndexBits = $clog2(`GBP_ENTRIES);
  localparam CVA6ConfigLocalPredictorIndexBits = $clog2(`LBP_ENTRIES);
  localparam CVA6ConfigLocalHistoryTableIndexBits = $clog2(`LHR_ENTRIES);
  localparam CVA6ConfigBimodalCtrBits = `BHT_CTR_BITS;
  localparam CVA6ConfigChoiceCtrBits = `CHOICE_CTR_BITS;
  localparam CVA6ConfigGlobalCtrBits = `GLOBAL_CTR_BITS;
  localparam CVA6ConfigLocalCtrBits = `LOCAL_CTR_BITS;

  // TAGE predictor
  localparam CVA6ConfigPower = `POWER;
  localparam CVA6ConfigNTagHistoryTables = `N_HISTORY_TABLES;
  localparam logic [`N_HISTORY_TABLES-1:0][31:0] CVA6ConfigHistLengths = (`N_HISTORY_TABLES*32)'(`HIST_LENGTHS);
  localparam logic [`N_HISTORY_TABLES-1:0][31:0] CVA6ConfigTagTableTagWidths = (`N_HISTORY_TABLES*32)'(`TAG_TABLE_TAG_WIDTHS);
  localparam logic [`N_HISTORY_TABLES-1:0][31:0] CVA6ConfigTagTableSizes = (`N_HISTORY_TABLES*32)'(`TAG_TABLE_SIZES);
  localparam CVA6ConfigTagTableCounterBits = `TAG_TABLE_COUNTER_BITS;
  localparam CVA6ConfigTagTableUBits = `TAG_TABLE_UBITS;
  localparam CVA6ConfigHistBufferBits = `HIST_BUFFER_BITS;
  localparam CVA6ConfigPathHistBits = `PATH_HIST_BITS;
  localparam CVA6ConfigUResetPeriod = `U_RESET_PERIOD;
  localparam CVA6ConfigNumUseAltOnNa = `NUM_USE_ALT_ON_NA;
  localparam CVA6ConfigInitialRstCtrValue = `INITIAL_RST_CTR_VALUE;
  localparam CVA6ConfigUseAltOnNaBits = `USE_ALT_ON_NA_BITS;

  localparam CVA6ConfigTvalEn = 1;

  localparam CVA6ConfigNrPMPEntries = 8;

  localparam CVA6ConfigPerfCounterEn = 1;

  localparam config_pkg::cache_type_t CVA6ConfigDcacheType = config_pkg::WT;

  localparam CVA6ConfigMmuPresent = 1;

  localparam CVA6ConfigRvfiTrace = 1;

  localparam config_pkg::cva6_user_cfg_t cva6_cfg = '{
      XLEN: unsigned'(CVA6ConfigXlen),
      VLEN: unsigned'(64),
      FpgaEn: bit'(1),  // for Xilinx and Altera
      FpgaAlteraEn: bit'(0),  // for Altera (only)
      TechnoCut: bit'(0),
      SuperscalarEn: bit'(0),
      NrCommitPorts: unsigned'(2),
      AxiAddrWidth: unsigned'(CVA6ConfigAxiAddrWidth),
      AxiDataWidth: unsigned'(CVA6ConfigAxiDataWidth),
      AxiIdWidth: unsigned'(CVA6ConfigAxiIdWidth),
      AxiUserWidth: unsigned'(CVA6ConfigDataUserWidth),
      MemTidWidth: unsigned'(CVA6ConfigMemTidWidth),
      NrLoadBufEntries: unsigned'(CVA6ConfigNrLoadBufEntries),
      RVF: bit'(CVA6ConfigRVF),
      RVD: bit'(CVA6ConfigRVF),
      XF16: bit'(CVA6ConfigF16En),
      XF16ALT: bit'(CVA6ConfigF16AltEn),
      XF8: bit'(CVA6ConfigF8En),
      RVA: bit'(CVA6ConfigAExtEn),
      RVB: bit'(CVA6ConfigBExtEn),
      RVV: bit'(CVA6ConfigVExtEn),
      RVC: bit'(CVA6ConfigCExtEn),
      RVH: bit'(CVA6ConfigHExtEn),
      RVZCB: bit'(CVA6ConfigZcbExtEn),
      RVZCMP: bit'(CVA6ConfigZcmpExtEn),
      XFVec: bit'(CVA6ConfigFVecEn),
      CvxifEn: bit'(CVA6ConfigCvxifEn),
      RVZiCond: bit'(CVA6ConfigRVZiCond),
      RVZicntr: bit'(1),
      RVZihpm: bit'(1),
      NrScoreboardEntries: unsigned'(CVA6ConfigNrScoreboardEntries),
      PerfCounterEn: bit'(CVA6ConfigPerfCounterEn),
      MmuPresent: bit'(CVA6ConfigMmuPresent),
      RVS: bit'(1),
      RVU: bit'(1),
      HaltAddress: 64'h800,
      ExceptionAddress: 64'h808,
      RASDepth: unsigned'(CVA6ConfigRASDepth),
      BTBEntries: unsigned'(CVA6ConfigBTBEntries),
      DmBaseAddress: 64'h0,
      TvalEn: bit'(CVA6ConfigTvalEn),
      DirectVecOnly: bit'(0),
      NrPMPEntries: unsigned'(CVA6ConfigNrPMPEntries),
      PMPCfgRstVal: {64{64'h0}},
      PMPAddrRstVal: {64{64'h0}},
      PMPEntryReadOnly: 64'd0,
      NOCType: config_pkg::NOC_TYPE_AXI4_ATOP,
      NrNonIdempotentRules: unsigned'(2),
      NonIdempotentAddrBase: 1024'({64'b0, 64'b0}),
      NonIdempotentLength: 1024'({64'b0, 64'b0}),
      NrExecuteRegionRules: unsigned'(3),
      ExecuteRegionAddrBase: 1024'({64'h8000_0000, 64'h1_0000, 64'h0}),
      ExecuteRegionLength: 1024'({64'h40000000, 64'h10000, 64'h1000}),
      NrCachedRegionRules: unsigned'(1),
      CachedRegionAddrBase: 1024'({64'h8000_0000}),
      CachedRegionLength: 1024'({64'h40000000}),
      MaxOutstandingStores: unsigned'(7),
      DebugEn: bit'(1),
      AxiBurstWriteEn: bit'(0),
      IcacheByteSize: unsigned'(CVA6ConfigIcacheByteSize),
      IcacheSetAssoc: unsigned'(CVA6ConfigIcacheSetAssoc),
      IcacheLineWidth: unsigned'(CVA6ConfigIcacheLineWidth),
      DCacheType: CVA6ConfigDcacheType,
      DcacheByteSize: unsigned'(CVA6ConfigDcacheByteSize),
      DcacheSetAssoc: unsigned'(CVA6ConfigDcacheSetAssoc),
      DcacheLineWidth: unsigned'(CVA6ConfigDcacheLineWidth),
      DataUserEn: unsigned'(CVA6ConfigDataUserEn),
      WtDcacheWbufDepth: int'(CVA6ConfigWtDcacheWbufDepth),
      FetchUserWidth: unsigned'(CVA6ConfigFetchUserWidth),
      FetchUserEn: unsigned'(CVA6ConfigFetchUserEn),
      InstrTlbEntries: int'(16),
      DataTlbEntries: int'(16),
      UseSharedTlb: bit'(0),
      SharedTlbDepth: int'(64),
      NrLoadPipeRegs: int'(CVA6ConfigNrLoadPipeRegs),
      NrStorePipeRegs: int'(CVA6ConfigNrStorePipeRegs),
      DcacheIdWidth: int'(CVA6ConfigDcacheIdWidth),
      BranchPredictorImpl: config_pkg::bp_t'(CVA6ConfigBranchPredictorImpl),
      BHTEntries: unsigned'(CVA6ConfigBHTEntries),
      ChoicePredictorSize: unsigned'(CVA6ConfigChoicePredictorSize),
      GlobalPredictorSize: unsigned'(CVA6ConfigGlobalPredictorSize),
      LocalPredictorSize: unsigned'(CVA6ConfigLocalPredictorSize),
      LocalHistoryTableSize: unsigned'(CVA6ConfigLocalHistoryTableSize),
      BHTIndexBits: unsigned'(CVA6ConfigBHTIndexBits),
      ChoicePredictorIndexBits: unsigned'(CVA6ConfigChoicePredictorIndexBits),
      GlobalPredictorIndexBits: unsigned'(CVA6ConfigGlobalPredictorIndexBits),
      LocalPredictorIndexBits: unsigned'(CVA6ConfigLocalPredictorIndexBits),
      LocalHistoryTableIndexBits: unsigned'(CVA6ConfigLocalHistoryTableIndexBits),
      BimodalCtrBits: unsigned'(CVA6ConfigBimodalCtrBits),
      ChoiceCtrBits: unsigned'(CVA6ConfigChoiceCtrBits),
      GlobalCtrBits: unsigned'(CVA6ConfigGlobalCtrBits),
      LocalCtrBits: unsigned'(CVA6ConfigLocalCtrBits),
      // TAGE predictor
      power: unsigned'(CVA6ConfigPower),
      nTagHistoryTables: unsigned'(CVA6ConfigNTagHistoryTables),
      histLengths: (`N_HISTORY_TABLES*32)'(CVA6ConfigHistLengths),
      tagTableTagWidths: (`N_HISTORY_TABLES*32)'(CVA6ConfigTagTableTagWidths),
      tagTableSizes: (`N_HISTORY_TABLES*32)'(CVA6ConfigTagTableSizes),
      tagTableCounterBits: unsigned'(CVA6ConfigTagTableCounterBits),
      tagTableUBits: unsigned'(CVA6ConfigTagTableUBits),
      histBufferBits: unsigned'(CVA6ConfigHistBufferBits),
      pathHistBits: unsigned'(CVA6ConfigPathHistBits),
      uResetPeriod: unsigned'(CVA6ConfigUResetPeriod),
      numUseAltOnNa: unsigned'(CVA6ConfigNumUseAltOnNa),
      initialRstCtrValue: unsigned'(CVA6ConfigInitialRstCtrValue),
      useAltOnNaBits: unsigned'(CVA6ConfigUseAltOnNaBits)
  };
endpackage
