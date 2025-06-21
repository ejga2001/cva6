/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

class BHTShadow #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter int unsigned NR_ENTRIES = 1024
);
    // the last bit is always zero, we don't need it for indexing
    localparam OFFSET = CVA6Cfg.RVC == 1'b1 ? 1 : 2;
    // re-shape the branch history table
    localparam NR_ROWS = NR_ENTRIES / CVA6Cfg.INSTR_PER_FETCH;
    // number of bits needed to index the row
    localparam ROW_ADDR_BITS = $clog2(CVA6Cfg.INSTR_PER_FETCH);
    localparam ROW_INDEX_BITS = CVA6Cfg.RVC == 1'b1 ? $clog2(CVA6Cfg.INSTR_PER_FETCH) : 1;
    // number of bits we should use for prediction
    localparam PREDICTION_BITS = $clog2(NR_ROWS) + OFFSET + ROW_ADDR_BITS;

    localparam CTR_MAX_VAL = (1 << CVA6Cfg.BimodalCtrBits) - 1;

    localparam INDEX_BITS = $clog2(NR_ROWS);

    localparam type bht_t = struct packed {
        logic                              valid;
        logic [CVA6Cfg.BimodalCtrBits-1:0] saturation_counter;
    };

    local bht_t data [NR_ROWS][CVA6Cfg.INSTR_PER_FETCH-1:0];

    function automatic new;
        for (int i = 0; i < NR_ROWS; i++) begin
            for (int j = 0; j < CVA6Cfg.INSTR_PER_FETCH; j++) begin
                data[i][j] = '0;
            end
        end
    endfunction : new

    function automatic void set_data(
        int index,
        int row_index,
        int data
    );
        this.data[index][row_index] = bht_t'(data);
    endfunction : set_data

    function automatic bht_prediction_t output_bht (
        input logic [CVA6Cfg.VLEN-1:0] vpc_i,
        input logic [CVA6Cfg.INSTR_PER_FETCH-1:0] row_index
    );
        logic [INDEX_BITS-1:0] index;

        index = vpc_i[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET];

        return {data[index][row_index].valid, data[index][row_index].saturation_counter[CVA6Cfg.BimodalCtrBits-1], index};
    endfunction

    function automatic void update_bht (
        input bht_update_t bht_update_i
    );
        bp_metadata_t metadata;
        logic [INDEX_BITS-1:0] index;
        logic [ROW_INDEX_BITS-1:0]  row_index;

        metadata = bht_update_i.metadata;
        index = metadata.index;
        row_index = bht_update_i.pc[ROW_ADDR_BITS+OFFSET-1:OFFSET];

        if (bht_update_i.valid) begin
            data[index][row_index].valid = bht_update_i.valid;
            if (data[index][row_index].saturation_counter == CTR_MAX_VAL) begin
                // we can safely decrease it
                if (~bht_update_i.taken)
                    data[index][row_index].saturation_counter = data[index][row_index].saturation_counter - 1;
                else data[index][row_index].saturation_counter = CTR_MAX_VAL;
                // then check if it saturated in the negative regime e.g.: branch not taken
            end else if (data[index][row_index].saturation_counter == 0) begin
                // we can safely increase it
                if (bht_update_i.taken)
                    data[index][row_index].saturation_counter = data[index][row_index].saturation_counter + 1;
                else data[index][row_index].saturation_counter = 0;
            end else begin  // otherwise we are not in any boundaries and can decrease or increase it
                if (bht_update_i.taken)
                    data[index][row_index].saturation_counter = data[index][row_index].saturation_counter + 1;
                else data[index][row_index].saturation_counter = data[index][row_index].saturation_counter - 1;
            end
        end
    endfunction
    
endclass