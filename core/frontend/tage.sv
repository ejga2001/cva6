/*
 * Copyright (c) 2024. All rights reserved.
 * Created by enrique, 11/3/25
 */

module tage #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg),
    parameter type tage_metadata_t = logic,
    parameter type tage_update_t = logic,
    parameter type tage_prediction_t = logic
) (
    // Subsystem Clock - SUBSYSTEM
    input logic clk_i,
    // Asynchronous reset active low - SUBSYSTEM
    input logic rst_ni,
    // Branch prediction flush request - zero
    input logic flush_bp_i,
    // Debug mode state - CSR
    input logic debug_mode_i,
    // Virtual PC - CACHE
    input logic [CVA6Cfg.VLEN-1:0] vpc_i,
    // Update TAGE with resolved address - EXECUTE
    input tage_update_t tage_update_i,
    // Final prediction from TAGE - FRONTEND
    output tage_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] tage_prediction_o
);
    localparam U_RESET_CTR_BITS = $clog2(CVA6Cfg.uResetPeriod);
    localparam N_TAG_TABLES_BITS = $clog2(CVA6Cfg.nTagHistoryTables);
    // the last bit is always zero, we don't need it for indexing
    localparam OFFSET = CVA6Cfg.RVC == 1'b1 ? 1 : 2;
    // number of bits needed to index the row
    localparam ROW_ADDR_BITS = $clog2(CVA6Cfg.INSTR_PER_FETCH);
    // number of bits needed to index a column inside a row
    localparam ROW_INDEX_BITS = CVA6Cfg.RVC == 1'b1 ? $clog2(CVA6Cfg.INSTR_PER_FETCH) : 1;
    // Bimodal component metadata
    localparam type bht_metadata_t = struct packed {
        logic [CVA6Cfg.BHTIndexBits-1:0] index;
    };
    // Bimodal component update structure
    localparam type bht_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;     // update at PC
        logic                    taken;
        bht_metadata_t           metadata;
    };
    // TAGE component update structure
    localparam type tage_component_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;
        logic                    taken;
        logic                    alloc;
        logic                    update_u_en;
        logic                    mispredict;
        logic                    rst_us;
    };
    // Bimodal component output
    localparam type bht_prediction_t = struct packed {
        logic                    valid;
        logic                    taken;
        bht_metadata_t           metadata;
    };
    // TAGE component output
    localparam type tage_component_pred_t = struct packed {
        logic                                         valid;
        logic                                         taken;
        logic                                         tag_match;
        logic                                         pseudo_new_alloc;
    };

    function automatic logic signed [CVA6Cfg.useAltOnNaBits-1:0] update_use_alt_on_na_ctr(
        input logic signed [CVA6Cfg.useAltOnNaBits-1:0] ctr,
        input logic taken
    );
        logic signed [CVA6Cfg.useAltOnNaBits-1:0] ctr_updated;

        if (taken) begin
            if (ctr < ((1 << (CVA6Cfg.useAltOnNaBits - 1)) - 1))
                ctr_updated = ctr + 1;
            else
                ctr_updated = ctr;
        end else begin
            if (ctr > -(1 << (CVA6Cfg.useAltOnNaBits - 1)))
                ctr_updated = ctr - 1;
            else
                ctr_updated = ctr;
        end

        return ctr_updated;
    endfunction

    // Registers
    logic [U_RESET_CTR_BITS-1:0] u_reset_ctr_q, u_reset_ctr_d;
    logic signed [CVA6Cfg.useAltOnNaBits-1:0] use_alt_on_na_q, use_alt_on_na_d;
    logic [CVA6Cfg.histBufferBits-1:0] gHist_q, gHist_d;
    logic [CVA6Cfg.pathHistBits-1:0] pathHist_q, pathHist_d;

    // Update signals
    bht_update_t bht_update;
    tage_component_update_t [CVA6Cfg.nTagHistoryTables:1] tage_component_updates;
    logic [ROW_INDEX_BITS-1:0] update_row_index;
    bht_metadata_t update_bht_metadata;
    tage_metadata_t update_tage_metadata;

    // Output signals
    bht_metadata_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_metadata;
    tage_metadata_t [CVA6Cfg.INSTR_PER_FETCH-1:0] tage_metadata;
    bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction;
    tage_component_pred_t [CVA6Cfg.nTagHistoryTables:1][CVA6Cfg.INSTR_PER_FETCH-1:0] tage_pred;
    logic [CVA6Cfg.nTagHistoryTables:1][CVA6Cfg.INSTR_PER_FETCH-1:0] u_is_null;
    logic [CVA6Cfg.nTagHistoryTables:1] doing_u_rst;

    // Table identifiers
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0][N_TAG_TABLES_BITS-1:0] longest_match_id, alt_id;
    logic [N_TAG_TABLES_BITS-1:0] start_id, alloc_id;

    // Intermediate signals
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] found_longest_match, found_alt_pred;
    logic alloc;
    logic [1:0] nrand;
    logic found_entry;
    logic rst_us_q, rst_us_d;

    // 2-bit Random Number Generator
    tage_lfsr #(
        .NBITS(2),
        .WIDTH(4)
    ) i_tage_lshr (
        .clk_i,
        .rst_ni,
        .rand_o(nrand)
    );

    // Bimodal and TAGE components instantiation
    bht #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bht_metadata_t),
        .NR_ENTRIES(CVA6Cfg.BHTEntries)
    ) i_bht (
        .clk_i,
        .rst_ni,
        .flush_bp_i      (flush_bp_i),
        .debug_mode_i,
        .vpc_i           (vpc_i),
        .bht_update_i    (bht_update),
        .bht_prediction_o(bht_prediction)
    );

    for (genvar i = 1; i <= CVA6Cfg.nTagHistoryTables; i++) begin : gen_tage_components
        tage_component #(
            .CVA6Cfg(CVA6Cfg),
            .TABLE_IDX(i),
            .TAG_TABLE_SIZE(CVA6Cfg.tagTableSizes[i-1]),
            .TAG_WIDTH(CVA6Cfg.tagTableTagWidths[i-1]),
            .HISTORY_LENGTH(CVA6Cfg.histLengths[i-1]),
            .tage_component_pred_t(tage_component_pred_t),
            .tage_component_update_t(tage_component_update_t)
        ) i_tage_component (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .vpc_i(vpc_i),
            .gHist_i(gHist_q[CVA6Cfg.histLengths[i-1]-1:0]),
            .pathHist_i(pathHist_q),
            .tage_component_update_i(tage_component_updates[i]),
            .update_ghist_i(update_tage_metadata.ghist[CVA6Cfg.histLengths[i-1]-1:0]),
            .update_phist_i(update_tage_metadata.phist),
            .tage_pred_o(tage_pred[i]),
            .u_is_null_o(u_is_null[i]),
            .doing_u_rst_o(doing_u_rst[i])
        );
    end

    always_comb begin : output_tage
        longest_match_id = '0;
        alt_id = '0;
        for (int slot = 0; slot < CVA6Cfg.INSTR_PER_FETCH; slot++) begin
            // Find the longest match
            found_longest_match[slot] = 1'b0;
            found_alt_pred[slot] = 1'b0;
            for (int i = CVA6Cfg.nTagHistoryTables; i > 0; i--) begin
                if (tage_pred[i][slot].tag_match & ~found_longest_match[slot]) begin
                    longest_match_id[slot] = N_TAG_TABLES_BITS'(i);
                    found_longest_match[slot] = 1'b1;
                end
            end
            // Find the alt pred
            for (int i = CVA6Cfg.nTagHistoryTables - 1; i > 0; i--) begin
                if ((tage_pred[i][slot].tag_match & ~found_alt_pred[slot]) 
                    && (N_TAG_TABLES_BITS'(i) != longest_match_id[slot])) begin
                    alt_id[slot] = N_TAG_TABLES_BITS'(i);
                    found_alt_pred[slot] = 1'b1;
                end
            end
            if (longest_match_id[slot] > N_TAG_TABLES_BITS'(1'b0)) begin
                if (alt_id[slot] > N_TAG_TABLES_BITS'(1'b0)) begin
                    tage_metadata[slot].alt_valid = tage_pred[alt_id][slot].valid;
                    tage_metadata[slot].alt_taken = tage_pred[alt_id][slot].taken;
                    tage_metadata[slot].alt_id = alt_id[slot];
                end else begin
                    tage_metadata[slot].alt_valid = bht_prediction[slot].valid;
                    tage_metadata[slot].alt_taken = bht_prediction[slot].taken;
                    tage_metadata[slot].alt_id = N_TAG_TABLES_BITS'(1'b0);
                end
                tage_metadata[slot].longest_match_valid = tage_pred[longest_match_id][slot].valid;
                tage_metadata[slot].longest_match_taken = tage_pred[longest_match_id][slot].taken;
                tage_metadata[slot].longest_match_id = longest_match_id[slot];
                tage_metadata[slot].pseudo_new_alloc = tage_pred[longest_match_id][slot].pseudo_new_alloc;
                if (use_alt_on_na_q[CVA6Cfg.useAltOnNaBits-1] | ~tage_metadata[slot].pseudo_new_alloc) begin
                    tage_prediction_o[slot].valid = tage_metadata[slot].longest_match_valid;
                    tage_prediction_o[slot].taken = tage_metadata[slot].longest_match_taken;
                end else begin
                    tage_prediction_o[slot].valid = tage_metadata[slot].alt_valid;
                    tage_prediction_o[slot].taken = tage_metadata[slot].alt_taken;
                end
            end else begin
                tage_prediction_o[slot].valid = bht_prediction[slot].valid;
                tage_prediction_o[slot].taken = bht_prediction[slot].taken;
                tage_metadata[slot].longest_match_valid = bht_prediction[slot].valid;
                tage_metadata[slot].longest_match_taken = bht_prediction[slot].taken;
                tage_metadata[slot].longest_match_id = N_TAG_TABLES_BITS'(1'b0);
                tage_metadata[slot].alt_valid = bht_prediction[slot].valid;
                tage_metadata[slot].alt_taken = bht_prediction[slot].taken;
                tage_metadata[slot].alt_id = N_TAG_TABLES_BITS'(1'b0);
                tage_metadata[slot].pseudo_new_alloc = 1'b0;
            end
            bht_metadata[slot] = bht_prediction[slot].metadata;
            tage_metadata[slot].bht_index = bht_metadata[slot].index;
            tage_metadata[slot].ghist = gHist_q;
            tage_metadata[slot].phist = pathHist_q;
            for (int i = 1; i <= CVA6Cfg.nTagHistoryTables; i++) begin
                tage_metadata[slot].u_is_null[i] = u_is_null[i][slot];
            end
            tage_prediction_o[slot].metadata = tage_metadata[slot];
        end
    end

    if (CVA6Cfg.RVC) begin : gen_update_row_index
        assign update_row_index = tage_update_i.pc[ROW_ADDR_BITS+OFFSET-1:OFFSET];
    end else begin
        assign update_row_index = '0;
    end

    assign update_tage_metadata = tage_update_i.metadata;

    always_comb begin : update_tage
        bht_update = '0;
        tage_component_updates = '0;
        start_id = '0;
        alloc_id = '0;
        alloc = 1'b0;
        found_entry = 1'b0;
        rst_us_d = rst_us_q;
        use_alt_on_na_d = use_alt_on_na_q;
        u_reset_ctr_d = u_reset_ctr_q;
        gHist_d = gHist_q;
        pathHist_d = pathHist_q;
        for (int slot = 0; slot < CVA6Cfg.INSTR_PER_FETCH; slot++) begin
            if (update_row_index == ROW_INDEX_BITS'(slot)) begin
                if (update_tage_metadata.longest_match_id < N_TAG_TABLES_BITS'(CVA6Cfg.nTagHistoryTables)) begin
                    alloc = tage_update_i.mispredict;
                end
                if (update_tage_metadata.longest_match_id > 0) begin
                    if (update_tage_metadata.pseudo_new_alloc) begin
                        if (update_tage_metadata.longest_match_valid
                            && (update_tage_metadata.longest_match_taken == tage_update_i.taken)) begin
                            alloc = 1'b0;
                        end
                        if ((update_tage_metadata.longest_match_valid & update_tage_metadata.alt_valid) &&
                            (update_tage_metadata.longest_match_taken != update_tage_metadata.alt_taken)) begin
                            use_alt_on_na_d = update_use_alt_on_na_ctr(use_alt_on_na_q,
                                update_tage_metadata.alt_taken == tage_update_i.taken);
                        end
                    end
                end
                if (alloc) begin
                    // Start searching from table start_id
                    start_id = update_tage_metadata.longest_match_id + 1;
                    if (nrand[0] && (start_id < N_TAG_TABLES_BITS'(CVA6Cfg.nTagHistoryTables))) begin
                        start_id = start_id + 1;
                        if (nrand[1] && (start_id < N_TAG_TABLES_BITS'(CVA6Cfg.nTagHistoryTables))) begin
                            start_id = start_id + 1;
                        end
                    end
                    for (int i = 1; i <= CVA6Cfg.nTagHistoryTables; i++) begin
                        if (i >= start_id && update_tage_metadata.u_is_null[i]) begin
                            alloc_id = N_TAG_TABLES_BITS'(i);
                            found_entry = 1'b1;
                        end
                    end
                    if (~found_entry) begin
                        alloc_id = N_TAG_TABLES_BITS'(CVA6Cfg.nTagHistoryTables);
                    end
                end
                // TAGE Update
                for (int i = 1; i <= CVA6Cfg.nTagHistoryTables; i++) begin
                    if ((update_tage_metadata.longest_match_id == N_TAG_TABLES_BITS'(i))
                    || (alloc_id == N_TAG_TABLES_BITS'(i))
                    || ((update_tage_metadata.alt_id == N_TAG_TABLES_BITS'(i))
                        && update_tage_metadata.u_is_null[update_tage_metadata.longest_match_id])) begin
                        tage_component_updates[i].valid = tage_update_i.valid;
                        tage_component_updates[i].pc = tage_update_i.pc;
                        tage_component_updates[i].taken = tage_update_i.taken;
                        if (update_tage_metadata.longest_match_id == N_TAG_TABLES_BITS'(i)) begin
                            tage_component_updates[i].update_u_en = 1'b1;
                            tage_component_updates[i].mispredict = tage_update_i.mispredict;
                        end else if (alloc_id == N_TAG_TABLES_BITS'(i)) begin
                            tage_component_updates[i].alloc = alloc;
                        end
                    end
                    tage_component_updates[i].rst_us = rst_us_q;
                end
                if (update_tage_metadata.longest_match_id > 0) begin
                    // if the provider entry is not certified to be useful also update
                    // the alternate prediction
                    if (update_tage_metadata.alt_id == 0
                        && update_tage_metadata.u_is_null[update_tage_metadata.longest_match_id]) begin
                        bht_update.valid = tage_update_i.valid;
                        bht_update.pc = tage_update_i.pc;
                        bht_update.taken = tage_update_i.taken;
                    end
                end else begin
                    bht_update.valid = tage_update_i.valid;
                    bht_update.pc = tage_update_i.pc;
                    bht_update.taken = tage_update_i.taken;
                end
            end
        end
        if (tage_update_i.valid) begin
            // Update histories
            gHist_d = {gHist_q[CVA6Cfg.histBufferBits-2:0], tage_update_i.taken};
            pathHist_d = {pathHist_q[CVA6Cfg.pathHistBits-2:0], tage_update_i.pc[2]};
            // Update reset counter and handle u reset
            rst_us_d = (u_reset_ctr_q == U_RESET_CTR_BITS'(CVA6Cfg.uResetPeriod-1));
            if (~rst_us_q & ~(|doing_u_rst)) begin
                u_reset_ctr_d = u_reset_ctr_q + 1;
            end
        end
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            gHist_q <= '0;
            pathHist_q <= '0;
            u_reset_ctr_q <= CVA6Cfg.initialRstCtrValue;
            rst_us_q <= '0;
            use_alt_on_na_q <= '0;
        end else begin
            gHist_q <= gHist_d;
            pathHist_q <= pathHist_d;
            u_reset_ctr_q <= u_reset_ctr_d;
            rst_us_q <= rst_us_d;
            use_alt_on_na_q <= use_alt_on_na_d;
        end
    end
endmodule