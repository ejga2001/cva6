/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

class TournamentShadow #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter int unsigned MBP_ENTRIES = 256,
    parameter int unsigned GBP_ENTRIES = 256,
    parameter int unsigned LBP_ENTRIES = 256,
    parameter int unsigned LHR_ENTRIES = 256
);
    localparam type gbp_metadata_t = struct packed {
        logic [CVA6Cfg.GlobalPredictorIndexBits-1:0] index;
    };

    localparam type lbp_metadata_t = struct packed {
        logic [CVA6Cfg.LocalPredictorIndexBits-1:0] index;
    };

    localparam type gbp_prediction_t = struct packed {
        logic                    valid;
        logic                    taken;
        gbp_metadata_t           metadata;
    };

    localparam type lbp_prediction_t = struct packed {
        logic                    valid;
        logic                    taken;
        lbp_metadata_t           metadata;
    };

    localparam type gbp_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;     // update at PC
        logic                    taken;
        gbp_metadata_t           metadata;
    };

    localparam type lbp_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;     // update at PC
        logic                    taken;
        lbp_metadata_t           metadata;
    };

    tb_pkg::GBPShadow #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(gbp_update_t),
        .bht_prediction_t(gbp_prediction_t),
        .bp_metadata_t(gbp_metadata_t),
        .NR_ENTRIES(GBP_ENTRIES)
    ) gbp_shadow;
    
    tb_pkg::LBPShadow #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(lbp_update_t),
        .bht_prediction_t(lbp_prediction_t),
        .bp_metadata_t(lbp_metadata_t),
        .LBP_ENTRIES(LBP_ENTRIES),
        .LHR_ENTRIES(LHR_ENTRIES)
    ) lbp_shadow;
    
    tb_pkg::MBPShadow #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t),
        .NR_ENTRIES(MBP_ENTRIES)
    ) mbp_shadow;

    function automatic new;
        gbp_shadow = new;
        lbp_shadow = new;
        mbp_shadow = new;
    endfunction : new

    function automatic void set_gbp_data(
        int index,
        int row_index,
        int data
    );
        gbp_shadow.set_data(index, row_index, data);
    endfunction : set_gbp_data

    function automatic void set_lbp_data(
        int index,
        int row_index,
        int data
    );
        lbp_shadow.set_lbp_data(index, row_index, data);
    endfunction : set_lbp_data

    function automatic void set_lhr_data(
        int index,
        int row_index,
        int data
    );
        lbp_shadow.set_lhr_data(index, row_index, data);
    endfunction : set_lhr_data
    
    function automatic void set_mbp_data(
        int index,
        int row_index,
        int data
    );
        mbp_shadow.set_data(index, row_index, data);
    endfunction : set_mbp_data

    function automatic bht_prediction_t output_bht (
        input logic [CVA6Cfg.VLEN-1:0] vpc_i,
        input logic [CVA6Cfg.INSTR_PER_FETCH-1:0] row_index
    );
        bht_prediction_t bht_prediction;
        gbp_prediction_t gbp_prediction;
        lbp_prediction_t lbp_prediction;
        logic select_prediction;
        
        gbp_prediction = gbp_shadow.output_bht(vpc_i, row_index);
        lbp_prediction = lbp_shadow.output_bht(vpc_i, row_index);
        select_prediction = mbp_shadow.output_bht(vpc_i, row_index);

        bht_prediction.valid = (select_prediction == 0 ? lbp_prediction.valid : gbp_prediction.valid);
        bht_prediction.taken = (select_prediction == 0 ? lbp_prediction.taken : gbp_prediction.taken);
        bht_prediction.metadata.gindex = gbp_prediction.metadata.index;
        bht_prediction.metadata.gbp_valid = gbp_prediction.valid;
        bht_prediction.metadata.gbp_taken = gbp_prediction.taken;
        bht_prediction.metadata.lindex = lbp_prediction.metadata.index;
        bht_prediction.metadata.lbp_valid = lbp_prediction.valid;
        bht_prediction.metadata.lbp_taken = lbp_prediction.taken;

        return bht_prediction;
    endfunction

    function automatic void update_bht (
        input bht_update_t bht_update_i
    );
        gbp_update_t gbp_update;
        lbp_update_t lbp_update;

        gbp_update = {bht_update_i.valid, bht_update_i.pc, bht_update_i.taken, bht_update_i.metadata.gindex};
        lbp_update = {bht_update_i.valid, bht_update_i.pc, bht_update_i.taken, bht_update_i.metadata.lindex};

        gbp_shadow.update_bht(gbp_update);
        lbp_shadow.update_bht(lbp_update);
        mbp_shadow.update_bht(bht_update_i);
    endfunction
    
endclass