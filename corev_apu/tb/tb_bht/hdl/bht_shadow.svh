/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

class BHTShadow #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
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

    local ariane_pkg::bht_t data [NR_ROWS][CVA6Cfg.INSTR_PER_FETCH-1:0];

    function automatic new;
        for (int i = 0; i < NR_ROWS; i++) begin
            for (int j = 0; j < CVA6Cfg.INSTR_PER_FETCH; j++) begin
                data[i][j] = '0;
            end
        end
    endfunction : new

    function automatic ariane_pkg::bht_prediction_t output_bht (
        input logic [CVA6Cfg.VLEN-1:0] vpc_i
    );
        logic [$clog2(NR_ROWS)-1:0] index;
        logic [ROW_INDEX_BITS-1:0]  row_index;

        index = vpc_i[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET];
        row_index = vpc_i[ROW_ADDR_BITS+OFFSET-1:OFFSET];

        return {data[index][row_index].valid, data[index][row_index].saturation_counter[1]};
    endfunction

    function automatic ariane_pkg::bht_t update_bht (
        input bht_update_t bht_update_i
    );
        logic [$clog2(NR_ROWS)-1:0] index;
        logic [ROW_INDEX_BITS-1:0]  row_index;

        index = bht_update_i.pc[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET];
        row_index = bht_update_i.pc[ROW_ADDR_BITS+OFFSET-1:OFFSET];

        data[index][row_index].valid = bht_update_i.valid;
        if (data[index][row_index].saturation_counter == 2'b11) begin
            // we can safely decrease it
            if (bht_update_i.taken)
                data[index][row_index].saturation_counter = data[index][row_index].saturation_counter - 1;
            else data[index][row_index].saturation_counter = 2'b11;
            // then check if it saturated in the negative regime e.g.: branch not taken
        end else if (data[index][row_index].saturation_counter == 2'b00) begin
            // we can safely increase it
            if (bht_update_i.taken)
                data[index][row_index].saturation_counter = data[index][row_index].saturation_counter + 1;
            else data[index][row_index].saturation_counter = 2'b00;
        end else begin  // otherwise we are not in any boundaries and can decrease or increase it
            if (bht_update_i.taken)
                data[index][row_index].saturation_counter = data[index][row_index].saturation_counter + 1;
            else data[index][row_index].saturation_counter = data[index][row_index].saturation_counter - 1;
        end

        return data[index][row_index];
    endfunction
    
endclass