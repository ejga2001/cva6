/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 6/3/25
 */

module tage_component #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg),
    parameter TABLE_IDX = 1,
    parameter TAG_TABLE_SIZE = 512,
    parameter TAG_WIDTH = 5,
    parameter HISTORY_LENGTH = 9,
    parameter type tage_component_pred_t = logic,
    parameter type tage_component_update_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Virtual PC - CACHE
    input logic [CVA6Cfg.VLEN-1:0] vpc_i,
    // Partial Global History Register - TAGE
    input logic [HISTORY_LENGTH-1:0] gHist_i,
    // Path History Register - TAGE
    input logic [CVA6Cfg.pathHistBits-1:0] pathHist_i,
    // Update TAGE component with resolved address - EXECUTE
    input tage_component_update_t tage_component_update_i,
    // Update TAGE component with ghist - EXECUTE
    input logic [HISTORY_LENGTH-1:0] update_ghist_i,
    // Update TAGE component with phist - EXECUTE
    input logic [CVA6Cfg.pathHistBits-1:0] update_phist_i,
    // TAGE table prediction
    output tage_component_pred_t [CVA6Cfg.INSTR_PER_FETCH-1:0] tage_pred_o,
    // U counter null
    output logic [CVA6Cfg.INSTR_PER_FETCH-1:0] u_is_null_o,
    // Is this TAGE component resetting the u bit?
    output logic doing_u_rst_o
);
    // the last bit is always zero, we don't need it for indexing
    localparam OFFSET = CVA6Cfg.RVC == 1'b1 ? 1 : 2;
    // re-shape the branch history table
    localparam NR_ROWS = TAG_TABLE_SIZE / CVA6Cfg.INSTR_PER_FETCH;
    // number of bits needed to index the row
    localparam ROW_ADDR_BITS = $clog2(CVA6Cfg.INSTR_PER_FETCH);
    localparam ROW_INDEX_BITS = CVA6Cfg.RVC == 1'b1 ? $clog2(CVA6Cfg.INSTR_PER_FETCH) : 1;
    // number of bits we should use for prediction
    localparam PREDICTION_BITS = $clog2(NR_ROWS) + OFFSET + ROW_ADDR_BITS;
    // number of bits to index the table
    localparam IDX_WIDTH = $clog2(NR_ROWS);
    localparam type tage_entry_t = struct packed {
        logic                                          valid;
        logic signed [CVA6Cfg.tagTableCounterBits-1:0] ctr;
        logic [TAG_WIDTH-1:0]                          tag;
    };
    // number of bits of a tagged entry
    localparam TAGE_ENTRY_BITS = $bits(tage_entry_t);
    // number of bits of a TAGE component prediction
    localparam TAGE_PRED_BITS = $bits(tage_component_pred_t);

    function automatic logic [IDX_WIDTH-1:0] F(
        input logic [CVA6Cfg.pathHistBits-1:0] pathHist_i
    );
        localparam SIZE = HISTORY_LENGTH > CVA6Cfg.pathHistBits ? CVA6Cfg.pathHistBits : HISTORY_LENGTH;
        localparam TAG_TABLE_SIZE_BITS = $clog2(TAG_TABLE_SIZE);
        localparam A2_SHAMT = (TABLE_IDX >= TAG_TABLE_SIZE_BITS) ? (TABLE_IDX - TAG_TABLE_SIZE_BITS) : (TAG_TABLE_SIZE_BITS - TABLE_IDX);

        logic [31:0] A, A1, A2;

        A = 32'(pathHist_i[SIZE-1:0]);
        A1 = (A & (TAG_TABLE_SIZE - 1));
        A2 = (A >> TAG_TABLE_SIZE_BITS);
        A2 = ((A2 << TABLE_IDX) & (TAG_TABLE_SIZE - 1)) + (A2 >> A2_SHAMT);
        A = A1 ^ A2;
        A = ((A << TABLE_IDX) & (TAG_TABLE_SIZE - 1)) + (A >> A2_SHAMT);

        return IDX_WIDTH'(A);
    endfunction

    function automatic logic [IDX_WIDTH-1:0] compute_folded_hist_idx(
        input logic [HISTORY_LENGTH-1:0] hist_i
    );
        localparam N_CHUNKS = (HISTORY_LENGTH + IDX_WIDTH - 1) / IDX_WIDTH;
        localparam REMAINDER = HISTORY_LENGTH - ((N_CHUNKS-1)*IDX_WIDTH);

        logic [IDX_WIDTH-1:0] result;

        result = '0;

        for (int i = 0; i < N_CHUNKS - 1; i++) begin
            result = result ^ hist_i[i*IDX_WIDTH +: IDX_WIDTH];
        end

        result[REMAINDER-1:0] = result[REMAINDER-1:0] ^ hist_i[HISTORY_LENGTH-1 -: REMAINDER];

        return result;
    endfunction : compute_folded_hist_idx

    function automatic logic [TAG_WIDTH-1:0] compute_folded_hist_tag(
        input logic [HISTORY_LENGTH-1:0] hist_i
    );
        localparam N_CHUNKS = (HISTORY_LENGTH + TAG_WIDTH - 1) / TAG_WIDTH;
        localparam REMAINDER = HISTORY_LENGTH - ((N_CHUNKS-1)*TAG_WIDTH);

        logic [TAG_WIDTH-1:0] result;

        result = '0;

        for (int i = 0; i < N_CHUNKS - 1; i++) begin
            result = result ^ hist_i[i*TAG_WIDTH +: TAG_WIDTH];
        end

        result[REMAINDER-1:0] = result[REMAINDER-1:0] ^ hist_i[(HISTORY_LENGTH-1) -: REMAINDER];

        return result;
    endfunction : compute_folded_hist_tag

    function automatic logic [IDX_WIDTH-1:0] hpc(
        input logic [CVA6Cfg.VLEN-1:0] pc_i,
        input logic [HISTORY_LENGTH-1:0] gHist_i,
        input logic [CVA6Cfg.pathHistBits-1:0] pathHist_i
    );
        localparam SIZE = HISTORY_LENGTH > CVA6Cfg.pathHistBits ? CVA6Cfg.pathHistBits : HISTORY_LENGTH;
        localparam TAG_TABLE_SIZE_BITS = $clog2(TAG_TABLE_SIZE);
        localparam SHAMT = (TABLE_IDX >= TAG_TABLE_SIZE_BITS) ? (TABLE_IDX - TAG_TABLE_SIZE_BITS) : (TAG_TABLE_SIZE_BITS - TABLE_IDX);

        return pc_i[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET]
            ^ (pc_i[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET] >> (SHAMT + 1))
            ^ compute_folded_hist_idx(gHist_i)
            ^ F(pathHist_i);
    endfunction : hpc

    function automatic logic [TAG_WIDTH-1:0] htag(
        input logic [CVA6Cfg.VLEN-1:0] vpc_i,
        input logic [HISTORY_LENGTH-1:0] gHist_i
    );
        return vpc_i[(ROW_ADDR_BITS+OFFSET)+:TAG_WIDTH] ^ compute_folded_hist_tag(gHist_i);
    endfunction : htag

    function automatic logic [CVA6Cfg.tagTableUBits-1:0] update_u(
        input logic [CVA6Cfg.tagTableUBits-1:0] u,
        input logic mispredict,
        input logic update_u_en,
        input logic do_rst_us
    );
        logic [CVA6Cfg.tagTableUBits-1:0] u_updated;

        if (do_rst_us) begin
            u_updated = {1'b0, u[CVA6Cfg.tagTableUBits-1:1]};
        end else if (update_u_en) begin
            if (mispredict) begin
                if (u > 0)
                    u_updated = u - 1;
                else
                    u_updated = (CVA6Cfg.tagTableUBits)'(0);
            end else begin
                if (u < ((1 << CVA6Cfg.tagTableUBits) - 1))
                    u_updated = u + 1;
                else
                    u_updated = u;
            end
        end else
            u_updated = u;

        return u_updated;
    endfunction

    function automatic logic signed [CVA6Cfg.tagTableCounterBits-1:0] update_ctr(
        input logic signed [CVA6Cfg.tagTableCounterBits-1:0] ctr,
        input logic taken
    );
        logic signed [CVA6Cfg.tagTableCounterBits-1:0] ctr_updated;

        if (taken) begin
            if (ctr < ((1 << (CVA6Cfg.tagTableCounterBits - 1)) - 1))
                ctr_updated = ctr + 1;
            else
                ctr_updated = ctr;
        end else begin
            if (ctr > -(1 << (CVA6Cfg.tagTableCounterBits - 1)))
                ctr_updated = ctr - 1;
            else
                ctr_updated = ctr;
        end

        return ctr_updated;
    endfunction

    logic [IDX_WIDTH-1:0] index, update_index;
    logic [TAG_WIDTH-1:0] idx_tag, update_tag;
    logic [ROW_INDEX_BITS-1:0] update_row_index;

    // TAGE table BRAM
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] tage_we;
    logic [CVA6Cfg.INSTR_PER_FETCH*IDX_WIDTH-1:0] tage_read_address_0;
    logic [CVA6Cfg.INSTR_PER_FETCH*IDX_WIDTH-1:0] tage_read_address_1;
    logic [CVA6Cfg.INSTR_PER_FETCH*IDX_WIDTH-1:0] tage_write_address;
    logic [CVA6Cfg.INSTR_PER_FETCH*TAGE_ENTRY_BITS-1:0] tage_wdata;
    logic [CVA6Cfg.INSTR_PER_FETCH*TAGE_ENTRY_BITS-1:0] tage_rdata_0;
    logic [CVA6Cfg.INSTR_PER_FETCH*TAGE_ENTRY_BITS-1:0] tage_rdata_1;

    // U counters table BRAM
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] us_we;
    logic [CVA6Cfg.INSTR_PER_FETCH*IDX_WIDTH-1:0] us_read_address_0;
    logic [CVA6Cfg.INSTR_PER_FETCH*IDX_WIDTH-1:0] us_read_address_1;
    logic [CVA6Cfg.INSTR_PER_FETCH*IDX_WIDTH-1:0] us_write_address;
    logic [CVA6Cfg.INSTR_PER_FETCH*CVA6Cfg.tagTableUBits-1:0] us_wdata;
    logic [CVA6Cfg.INSTR_PER_FETCH*CVA6Cfg.tagTableUBits-1:0] us_rdata_0;
    logic [CVA6Cfg.INSTR_PER_FETCH*CVA6Cfg.tagTableUBits-1:0] us_rdata_1;

    tage_entry_t [CVA6Cfg.INSTR_PER_FETCH-1:0] tage_entry_updated;
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0][CVA6Cfg.tagTableUBits-1:0] us_entry_updated;

    // Registers for handling graceful reset of U counters
    logic do_rst_us;
    logic [IDX_WIDTH-1:0] u_index;
    logic [IDX_WIDTH+ROW_INDEX_BITS:0] rst_u_index_q, rst_u_index_d;
    logic [ROW_INDEX_BITS-1:0] u_row_index;

    for (genvar i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin : gen_tage_table_ram
        AsyncThreePortRam #(
            .ADDR_WIDTH($clog2(NR_ROWS)),
            .DATA_DEPTH(NR_ROWS),
            .DATA_WIDTH(TAGE_ENTRY_BITS)
        ) i_tage_table_ram (
            .Clk_CI     (clk_i),
            .WrEn_SI    (tage_we[i]),
            .WrAddr_DI  (tage_write_address[i*IDX_WIDTH+:IDX_WIDTH]),
            .WrData_DI  (tage_wdata[i*TAGE_ENTRY_BITS+:TAGE_ENTRY_BITS]),
            .RdAddr_DI_0(tage_read_address_0[i*IDX_WIDTH+:IDX_WIDTH]),
            .RdAddr_DI_1(tage_read_address_1[i*IDX_WIDTH+:IDX_WIDTH]),
            .RdData_DO_0(tage_rdata_0[i*TAGE_ENTRY_BITS+:TAGE_ENTRY_BITS]),
            .RdData_DO_1(tage_rdata_1[i*TAGE_ENTRY_BITS+:TAGE_ENTRY_BITS])
        );
        AsyncThreePortRam #(
            .ADDR_WIDTH(IDX_WIDTH),
            .DATA_DEPTH(NR_ROWS),
            .DATA_WIDTH(CVA6Cfg.tagTableUBits)
        ) i_us_table_ram (
            .Clk_CI     (clk_i),
            .WrEn_SI    (us_we[i]),
            .WrAddr_DI  (us_write_address[i*IDX_WIDTH+:IDX_WIDTH]),
            .WrData_DI  (us_wdata[i*CVA6Cfg.tagTableUBits+:CVA6Cfg.tagTableUBits]),
            .RdAddr_DI_0(us_read_address_0[i*IDX_WIDTH+:IDX_WIDTH]),
            .RdAddr_DI_1(us_read_address_1[i*IDX_WIDTH+:IDX_WIDTH]),
            .RdData_DO_0(us_rdata_0[i*CVA6Cfg.tagTableUBits+:CVA6Cfg.tagTableUBits]),
            .RdData_DO_1(us_rdata_1[i*CVA6Cfg.tagTableUBits+:CVA6Cfg.tagTableUBits])
        );
    end

    // Output TAGE
    assign index = hpc(vpc_i, gHist_i, pathHist_i);
    assign idx_tag = htag(vpc_i, gHist_i);

    always_comb begin : output_tage_component
        for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
            tage_read_address_0[i*IDX_WIDTH+:IDX_WIDTH] = index;
            tage_pred_o[i].valid = tage_rdata_0[i*TAGE_ENTRY_BITS+TAGE_ENTRY_BITS-1];
            tage_pred_o[i].taken = ~tage_rdata_0[(i*TAGE_ENTRY_BITS+TAG_WIDTH+CVA6Cfg.tagTableCounterBits-1)];
            tage_pred_o[i].tag_match = tage_rdata_0[i*TAGE_ENTRY_BITS+:TAG_WIDTH] == idx_tag;
            tage_pred_o[i].pseudo_new_alloc = (tage_rdata_0[(i*TAGE_ENTRY_BITS+TAG_WIDTH)+:CVA6Cfg.tagTableCounterBits] == 0)
                || (tage_rdata_0[(i*TAGE_ENTRY_BITS+TAG_WIDTH)+:CVA6Cfg.tagTableCounterBits] == -1);
        end
    end

    always_comb begin : output_us_table
        for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
            us_read_address_0[i*IDX_WIDTH+:IDX_WIDTH] = index;
            u_is_null_o[i] = us_rdata_0[i*CVA6Cfg.tagTableUBits+:CVA6Cfg.tagTableUBits] == 0;
        end
    end

    assign doing_u_rst_o = ~rst_u_index_q[IDX_WIDTH+ROW_INDEX_BITS];

    // Update TAGE
    assign update_index = hpc(tage_component_update_i.pc, update_ghist_i, update_phist_i);
    assign update_tag = htag(tage_component_update_i.pc, update_ghist_i);
    if (CVA6Cfg.RVC) begin : gen_update_row_index
        assign update_row_index = tage_component_update_i.pc[ROW_ADDR_BITS+OFFSET-1:OFFSET];
    end else begin
        assign update_row_index = '0;
    end

    always_comb begin : gen_u_index
        // Check if it's necessary to partially reset the us table
        do_rst_us = ~rst_u_index_q[IDX_WIDTH+ROW_INDEX_BITS] & ~tage_component_update_i.alloc;

        // Compute indexes
        if (do_rst_us) begin
            u_index = rst_u_index_q[ROW_INDEX_BITS +: IDX_WIDTH];
            u_row_index = rst_u_index_q[ROW_INDEX_BITS-1:0];
        end else begin
            u_index = update_index;
            u_row_index = update_row_index;
        end
    end

    always_comb begin : update_tage_component
        tage_read_address_1 = '0;
        tage_entry_updated = '0;
        tage_we = '0;
        tage_write_address = '0;
        tage_wdata = '0;
        us_read_address_1 = '0;
        us_entry_updated = '0;
        us_we = '0;
        us_write_address = '0;
        us_wdata = '0;
        rst_u_index_d = rst_u_index_q;
        if (tage_component_update_i.valid) begin
            for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; ++i) begin
                if (update_row_index == ROW_INDEX_BITS'(i)) begin
                    tage_entry_updated[i].valid = 1'b1;
                    tage_we[i] = 1'b1;
                    tage_write_address[i*IDX_WIDTH+:IDX_WIDTH] = update_index;
                    us_we[i] = tage_component_update_i.update_u_en | tage_component_update_i.alloc | do_rst_us;
                    us_write_address[i*IDX_WIDTH+:IDX_WIDTH] = u_index;
                end
            end
        end else if (do_rst_us) begin
            for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; ++i) begin
                if (update_row_index == ROW_INDEX_BITS'(i)) begin
                    us_we[i] = 1'b1;
                    us_write_address[i*IDX_WIDTH+:IDX_WIDTH] = u_index;
                end
            end
        end
        // Update TAGE entry
        for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
            if (update_row_index == ROW_INDEX_BITS'(i)) begin
                // Read from TAGE table's BRAM
                tage_read_address_1[i*IDX_WIDTH+:IDX_WIDTH] = update_index;
                tage_entry_updated[i].ctr = tage_rdata_1[(i*TAGE_ENTRY_BITS+TAG_WIDTH) +: CVA6Cfg.tagTableCounterBits];
                tage_entry_updated[i].tag = tage_rdata_1[i*TAGE_ENTRY_BITS +: TAG_WIDTH];

                // Update prediction counter
                if (tage_component_update_i.alloc) begin
                    tage_entry_updated[i].tag = update_tag;
                    tage_entry_updated[i].ctr = tage_component_update_i.taken ? 0 : -1;
                end else begin
                    tage_entry_updated[i].ctr = update_ctr(tage_entry_updated[i].ctr, tage_component_update_i.taken);
                end

                // Write back to BRAM
                tage_wdata[i*TAGE_ENTRY_BITS+:TAGE_ENTRY_BITS] = tage_entry_updated[i];
            end
        end
        // Update U table entry
        for (int i = 0; i < CVA6Cfg.INSTR_PER_FETCH; i++) begin
            if (u_row_index == ROW_ADDR_BITS'(i)) begin
                // Read from us table's BRAM
                us_read_address_1[i*IDX_WIDTH+:IDX_WIDTH] = u_index;
                us_entry_updated[i] = us_rdata_1[i*CVA6Cfg.tagTableUBits+:CVA6Cfg.tagTableUBits];

                // Update useful counter
                if (tage_component_update_i.alloc) begin
                    us_entry_updated[i] = '0;
                end else begin
                    us_entry_updated[i] = update_u(us_entry_updated[i],
                                                   tage_component_update_i.mispredict,
                                                   tage_component_update_i.update_u_en,
                                                   do_rst_us);
                end

                // Write back to the BRAM
                us_wdata[i*CVA6Cfg.tagTableUBits+:CVA6Cfg.tagTableUBits] = us_entry_updated[i];
            end
        end
        // Update rst_u_index and rst_u_row_index
        if (tage_component_update_i.rst_us & rst_u_index_q[IDX_WIDTH+ROW_INDEX_BITS]) begin
            rst_u_index_d = '0;
        end else if (do_rst_us) begin
            rst_u_index_d = rst_u_index_q + 1; 
        end else begin
            rst_u_index_d = rst_u_index_q;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            rst_u_index_q <= {1'b1, {(IDX_WIDTH+ROW_INDEX_BITS){1'b0}}};
        end else begin
            rst_u_index_q <= rst_u_index_d;
        end
    end
endmodule