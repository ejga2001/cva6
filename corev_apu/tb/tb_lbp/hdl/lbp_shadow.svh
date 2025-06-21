/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

class LBPShadow #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter int unsigned LBP_ENTRIES = 512,
    parameter int unsigned LHR_ENTRIES = 512
);
    // the last bit is always zero, we don't need it for indexing
    localparam OFFSET = CVA6Cfg.RVC == 1'b1 ? 1 : 2;
    // re-shape the branch history table
    localparam NR_ROWS_LBP = LBP_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;
    // re-shape the LHR table
    localparam NR_ROWS_LHR = LHR_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;
    // number of bits needed to index the row
    localparam ROW_ADDR_BITS = $clog2(CVA6Cfg.INSTR_PER_FETCH);
    localparam ROW_INDEX_BITS = CVA6Cfg.RVC == 1'b1 ? $clog2(CVA6Cfg.INSTR_PER_FETCH) : 1;
    // number of bits we should use for prediction
    localparam HISTORY_BITS = $clog2(NR_ROWS_LHR) + OFFSET + ROW_ADDR_BITS;

    localparam CTR_MAX_VAL = (1 << CVA6Cfg.LocalCtrBits) - 1;

    localparam LHR_BITS = CVA6Cfg.LocalPredictorIndexBits;

    localparam type bht_t = struct packed {
        logic                              valid;
        logic [CVA6Cfg.LocalCtrBits-1:0] saturation_counter;
    };

    local bht_t lbp_data [NR_ROWS_LBP][CVA6Cfg.INSTR_PER_FETCH-1:0];
    local logic [LHR_BITS-1:0] lhr_data [NR_ROWS_LHR][CVA6Cfg.INSTR_PER_FETCH-1:0];

    function automatic new;
        for (int i = 0; i < NR_ROWS_LHR; i++) begin
            for (int j = 0; j < CVA6Cfg.INSTR_PER_FETCH; j++) begin
                lhr_data[i][j] = '0;
            end
        end
        for (int i = 0; i < NR_ROWS_LBP; i++) begin
            for (int j = 0; j < CVA6Cfg.INSTR_PER_FETCH; j++) begin
                lbp_data[i][j] = '0;
            end
        end
    endfunction : new

    function automatic void set_lhr_data(
        int index,
        int row_index,
        int lhr_data
    );
        this.lhr_data[index][row_index] = (LHR_BITS)'(lhr_data);
    endfunction : set_lhr_data

    function automatic void set_lbp_data(
        int index,
        int row_index,
        int lbp_data
    );
        this.lbp_data[index][row_index] = bht_t'(lbp_data);
    endfunction : set_lbp_data

    function automatic bht_prediction_t output_bht (
        input logic [CVA6Cfg.VLEN-1:0] vpc_i,
        input logic [CVA6Cfg.INSTR_PER_FETCH-1:0] row_index
    );
        logic [LHR_BITS-1:0] index;

        index = lhr_data[vpc_i[HISTORY_BITS-1:ROW_ADDR_BITS+OFFSET]][row_index];

        return {lbp_data[index][row_index].valid, lbp_data[index][row_index].saturation_counter[CVA6Cfg.LocalCtrBits-1], index};
    endfunction

    function automatic void update_bht (
        input bht_update_t bht_update_i
    );
        bp_metadata_t metadata;
        logic [$clog2(NR_ROWS_LHR)-1:0] lhr_index;
        logic [LHR_BITS-1:0] index;
        logic [ROW_INDEX_BITS-1:0]  row_index;

        metadata = bht_update_i.metadata;
        lhr_index = bht_update_i.pc[HISTORY_BITS-1:ROW_ADDR_BITS+OFFSET];
        index = metadata.index;
        row_index = bht_update_i.pc[ROW_ADDR_BITS+OFFSET-1:OFFSET];

        if (bht_update_i.valid) begin
            lhr_data[lhr_index][row_index] = {lhr_data[lhr_index][row_index][LHR_BITS-2:0], bht_update_i.taken};
            lbp_data[index][row_index].valid = bht_update_i.valid;
            if (lbp_data[index][row_index].saturation_counter == CTR_MAX_VAL) begin
                // we can safely decrease it
                if (~bht_update_i.taken)
                    lbp_data[index][row_index].saturation_counter = lbp_data[index][row_index].saturation_counter - 1;
                else lbp_data[index][row_index].saturation_counter = CTR_MAX_VAL;
                // then check if it saturated in the negative regime e.g.: branch not taken
            end else if (lbp_data[index][row_index].saturation_counter == 0) begin
                // we can safely increase it
                if (bht_update_i.taken)
                    lbp_data[index][row_index].saturation_counter = lbp_data[index][row_index].saturation_counter + 1;
                else lbp_data[index][row_index].saturation_counter = 0;
            end else begin  // otherwise we are not in any boundaries and can decrease or increase it
                if (bht_update_i.taken)
                    lbp_data[index][row_index].saturation_counter = lbp_data[index][row_index].saturation_counter + 1;
                else lbp_data[index][row_index].saturation_counter = lbp_data[index][row_index].saturation_counter - 1;
            end
        end
    endfunction
    
endclass