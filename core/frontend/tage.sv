/*
 * Copyright (c) 2024. All rights reserved.
 * Created by enrique, 11/3/25
 */

module tage #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = build_config_pkg::build_config(cva6_config_pkg::cva6_cfg),
    parameter type bht_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;     // update at PC
        logic                    taken;
    },
    parameter type tage_update_t = struct packed {
        logic                                valid;
        logic             [CVA6Cfg.VLEN-1:0] pc;
        logic                                taken;
        logic   [CVA6Cfg.histBufferSize-1:0] ghist;
        logic     [CVA6Cfg.pathHistBits-1:0] phist;
        logic                                pred_taken;
        logic                                provider_taken;
        logic                                alt_taken;
        logic [$clog2(CVA6Cfg.nTagHistoryTables)-1:0] pred_id;
        logic [$clog2(CVA6Cfg.nTagHistoryTables)-1:0] alt_id;
        logic [$clog2(CVA6Cfg.nTagHistoryTables)-1:0] u_is_null;
        logic                                mispredict;
        logic                                pseudo_new_alloc;
    },
    parameter type tage_component_pred_t = struct packed {
        logic                                          valid;
        logic                                          taken;
        logic                                          tag_match;
        logic                                          pseudo_new_alloc;
    },
    parameter type tage_prediction_t = struct packed {
        logic                                                            valid;
        logic                                                            pred_taken;
        logic                                                            provider_taken;
        logic                                                            alt_taken;
        logic [$clog2(CVA6Cfg.nTagHistoryTables)-1:0]                    pred_id;
        logic [$clog2(CVA6Cfg.nTagHistoryTables)-1:0]                    alt_id;
        logic [$clog2(CVA6Cfg.nTagHistoryTables)-1:0][CVA6Cfg.INSTR_PER_FETCH-1:0] u_is_null;
        logic                                                            pseudo_new_alloc;
    },
    parameter type tage_component_update_t = struct packed {
        logic                    valid;
        logic [CVA6Cfg.VLEN-1:0] pc;
        logic                    taken;
        logic                    alloc;
        logic                    update_ctr_en;
        logic                    update_u_en;
        logic                    rst_us;
        logic                    mispredict;
    }
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
    output tage_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] tage_prediction_o,
    // Global History register - FTQ
    output logic [CVA6Cfg.histBufferSize-1:0] ghist_o,
    // Path History register - FTQ
    output logic [CVA6Cfg.histBufferSize-1:0] phist_o
);
    localparam U_RESET_CTR_BITS = $clog2(CVA6Cfg.uResetPeriod);
    localparam N_TAG_TABLES_BITS = $clog2(CVA6Cfg.nTagHistoryTables);
    // the last bit is always zero, we don't need it for indexing
    localparam OFFSET = CVA6Cfg.RVC == 1'b1 ? 1 : 2;
    // number of bits needed to index the row
    localparam ROW_ADDR_BITS = $clog2(CVA6Cfg.INSTR_PER_FETCH);
    // number of bits needed to index a column inside a row
    localparam ROW_INDEX_BITS = CVA6Cfg.RVC == 1'b1 ? $clog2(CVA6Cfg.INSTR_PER_FETCH) : 1;

    function automatic logic signed [CVA6Cfg.useAltOnNaBits-1:0] update_use_alt_on_na_ctr(
        input logic signed [CVA6Cfg.useAltOnNaBits-1:0] ctr,
        input logic taken
    );
        logic signed [CVA6Cfg.useAltOnNaBits-1:0] ctr_updated;

        if (taken) begin
            if (ctr < ((1 << (CVA6Cfg.useAltOnNaBits - 1)) - 1))
                ctr_updated = ctr - 1;
            else
                ctr_updated = ctr;
        end else begin
            if (ctr > -(1 << (CVA6Cfg.useAltOnNaBits - 1)))
                ctr_updated = ctr + 1;
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

    // Output signals
    bht_prediction_t [CVA6Cfg.INSTR_PER_FETCH-1:0] bht_prediction;
    tage_component_pred_t [CVA6Cfg.nTagHistoryTables:1][CVA6Cfg.INSTR_PER_FETCH-1:0] tage_pred;
    logic [$clog2(CVA6Cfg.nTagHistoryTables):1][CVA6Cfg.INSTR_PER_FETCH-1:0] u_is_null;

    // Table identifiers
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0][N_TAG_TABLES_BITS-1:0] provider_id, alt_id;
    logic [N_TAG_TABLES_BITS-1:0] start_id, alloc_id;

    // Intermediate signals
    logic [CVA6Cfg.INSTR_PER_FETCH-1:0] found_longest_match, found_alt_pred;
    logic alloc, update_ctr_en, update_u_en;
    logic [1:0] nrand;
    logic found_entry;
    logic rst_us;

    // 2-bit Random Number Generator
    lshr #(
        .NBITS(2),
        .WIDTH(4)
    ) i_lshr (
        .clk_i,
        .rst_ni,
        .rand_o(nrand)
    );

    // BHT and TAGE components instantiation
    bht #(
        .CVA6Cfg   (CVA6Cfg),
        .bht_update_t(bht_update_t),
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
            .TAG_TABLE_SIZE(CVA6Cfg.tagTableSizes[i]),
            .TAG_WIDTH(CVA6Cfg.tagTableTagWidths[i]),
            .HISTORY_LENGTH(CVA6Cfg.histLengths[i]),
            .tage_component_pred_t(tage_component_pred_t),
            .tage_component_update_t(tage_component_update_t)
        ) i_tage_component (
            .clk_i(clk_i),
            .rst_ni(rst_ni),
            .vpc_i(vpc_i),
            .gHist_i(gHist_q[CVA6Cfg.histLengths[i]-1:0]),
            .pathHist_i(pathHist_q),
            .tage_component_update_i(tage_component_updates[i]),
            .update_ghist(tage_update_i.ghist[CVA6Cfg.histLengths[i]-1:0]),
            .update_phist(tage_update_i.phist),
            .tage_pred_o(tage_pred[i]),
            .u_is_null_o(u_is_null[i])
        );
    end

    always_comb begin : output_tage
        provider_id = '0;
        alt_id = '0;
        for (int slot = 0; slot < CVA6Cfg.INSTR_PER_FETCH; slot++) begin
            // Find the longest match
            found_longest_match[slot] = 1'b0;
            found_alt_pred[slot] = 1'b0;
            for (int i = CVA6Cfg.nTagHistoryTables; provider_id > 0; i--) begin
                if (tage_pred[i][slot].tag_match & ~found_longest_match[slot]) begin
                    provider_id[slot] = N_TAG_TABLES_BITS'(i);
                    found_longest_match[slot] = 1'b1;
                end
            end
            // Find the alt pred
            for (int i = CVA6Cfg.nTagHistoryTables - 1; i > 0; i--) begin
                if (tage_pred[i][slot].tag_match && ~found_alt_pred[slot] && i != provider_id[slot]) begin
                    alt_id[slot] = N_TAG_TABLES_BITS'(i);
                    found_alt_pred[slot] = 1'b1;
                end
            end
            if (provider_id[slot] > N_TAG_TABLES_BITS'(1'b0)) begin
                if (alt_id[slot] > N_TAG_TABLES_BITS'(1'b0)) begin
                    tage_prediction_o[slot].alt_taken = tage_pred[alt_id][slot].taken;
                    tage_prediction_o[slot].alt_id = alt_id[slot];
                end else begin
                    tage_prediction_o[slot].alt_taken = bht_prediction[slot].taken;
                    tage_prediction_o[slot].alt_id = N_TAG_TABLES_BITS'(1'b0);
                end
                tage_prediction_o[slot].provider_taken = ~tage_pred[provider_id][slot].taken;
                tage_prediction_o[slot].pseudo_new_alloc = tage_pred[provider_id][slot].pseudo_new_alloc;
                if (use_alt_on_na_q[CVA6Cfg.useAltOnNaBits-1] || ~tage_prediction_o[slot].pseudo_new_alloc) begin
                    tage_prediction_o[slot].pred_taken = tage_prediction_o[slot].provider_taken;
                    tage_prediction_o[slot].pred_id = provider_id[slot];
                end else begin
                    tage_prediction_o[slot].pred_taken = tage_prediction_o[slot].alt_taken;
                    tage_prediction_o[slot].pred_id = alt_id[slot];
                end
            end else begin
                tage_prediction_o[slot].valid = bht_prediction[slot].valid;
                tage_prediction_o[slot].pred_taken = bht_prediction[slot].taken;
                tage_prediction_o[slot].provider_taken = bht_prediction[slot].taken;
                tage_prediction_o[slot].alt_taken = bht_prediction[slot].taken;
                tage_prediction_o[slot].pred_id = N_TAG_TABLES_BITS'(1'b0);
                tage_prediction_o[slot].alt_id = N_TAG_TABLES_BITS'(1'b0);
                tage_prediction_o[slot].pseudo_new_alloc = 1'b0;
            end
        end
    end

    if (CVA6Cfg.RVC) begin : gen_update_row_index
        assign update_row_index = tage_update_i.pc[ROW_ADDR_BITS+OFFSET-1:OFFSET];
    end else begin
        assign update_row_index = '0;
    end

    always_comb begin : update_tage
        bht_update = '0;
        tage_component_updates = '0;
        start_id = '0;
        alloc_id = '0;
        alloc = 1'b0;
        found_entry = 1'b0;
        rst_us = 1'b0;
        use_alt_on_na_d = use_alt_on_na_q;
        u_reset_ctr_d = u_reset_ctr_q;
        gHist_d = gHist_q;
        pathHist_d = pathHist_q;
        if (tage_update_i.valid) begin
            for (int slot = 0; slot < CVA6Cfg.INSTR_PER_FETCH; slot++) begin
                if (update_row_index == ROW_INDEX_BITS'(slot)) begin
                    alloc = tage_update_i.mispredict && (tage_update_i.pred_id < N_TAG_TABLES_BITS'(CVA6Cfg.nTagHistoryTables));
                    if (tage_update_i.pred_id > 0) begin
                        if (tage_update_i.pseudo_new_alloc) begin
                            if (tage_update_i.provider_taken == tage_update_i.taken) begin
                                alloc = 1'b0;
                            end
                            if (tage_update_i.provider_taken != tage_update_i.alt_taken) begin
                                use_alt_on_na_valid = 1'b1;
                                use_alt_on_na_d = update_use_alt_on_na_ctr(use_alt_on_na_q,
                                    tage_update_i.alt_taken == tage_update_i.taken);
                            end
                        end
                    end
                    if (alloc) begin
                        // Start searching from table start_id
                        start_id = nrand + 1;
                        if (nrand[0] && tage_update_i.pred_id < N_TAG_TABLES_BITS'(CVA6Cfg.nTagHistoryTables)) begin
                            start_id = start_id + 1;
                            if (nrand[1] && tage_update_i.pred_id < N_TAG_TABLES_BITS'(CVA6Cfg.nTagHistoryTables)) begin
                                start_id = start_id + 1;
                            end
                        end
                        for (int i = 1; i <= CVA6Cfg.nTagHistoryTables; i++) begin
                            if (i >= start_id && tage_update_i.u_is_null[i] && ~found_entry) begin
                                alloc_id = N_TAG_TABLES_BITS'(i);
                                found_entry = 1'b1;
                            end
                        end
                        if (~found_entry) begin
                            alloc_id = start_id;
                        end
                    end
                    // Update reset counter and handle u reset
                    if (u_reset_ctr_q == 0) begin
                        rst_us = 1'b1;
                    end
                    u_reset_ctr_d = u_reset_ctr_q + 1;
                    // TAGE Update
                    if (tage_update_i.pred_id > 0) begin
                        for (int i = 1; i <= CVA6Cfg.nTagHistoryTables; i++) begin
                            tage_component_updates[i].valid = 1'b1;
                            tage_component_updates[i].pc = tage_update_i.pc;
                            tage_component_updates[i].ghist = tage_update_i.ghist;
                            tage_component_updates[i].phist = tage_update_i.phist;
                            tage_component_updates[i].taken = tage_update_i.taken;
                            tage_component_updates[i].mispredict = tage_update_i.mispredict;
                            tage_component_updates[i].rst_us = rst_us;
                            if (alloc_id == N_TAG_TABLES_BITS'(i)) begin
                                tage_component_updates[i].alloc = alloc;
                            end
                            if (tage_update_i.pred_id == N_TAG_TABLES_BITS'(i)) begin
                                tage_component_updates[i].update_ctr_en = 1'b1;
                                tage_component_updates[i].update_u_en = 1'b1;
                            end
                            // if the provider entry is not certified to be useful also update
                            // the alternate prediction
                            if (tage_update_i.alt_id == N_TAG_TABLES_BITS'(i)
                                && tage_update_i.u_is_null[tage_update_i.pred_id][slot]) begin
                                tage_component_updates[i].update_ctr_en = 1'b1;
                            end
                        end
                        // if the provider entry is not certified to be useful also update
                        // the alternate prediction
                        if (tage_update_i.alt_id == 0 && tage_update_i.u_is_null[tage_update_i.pred_id][slot]) begin
                            bht_update.valid = 1'b1;
                            bht_update.pc = tage_update_i.pc;
                            bht_update.taken = tage_update_i.taken;
                        end
                    end else begin
                        bht_update.valid = 1'b1;
                        bht_update.pc = tage_update_i.pc;
                        bht_update.taken = tage_update_i.taken;
                    end
                    // Update histories
                    gHist_d = {gHist_q[CVA6Cfg.histBufferBits-2:0], tage_update_i.taken};
                    pathHist_d = {pathHist_q[CVA6Cfg.pathHistBits-2:0], tage_update_i.pc[2]};
                end
            end
        end
    end

    always_ff @(posedge clk_i, negedge rst_ni) begin
        if (!rst_ni) begin
            gHist_q <= '0;
            pathHist_q <= '0;
            u_reset_ctr_q <= '0;
            use_alt_on_na_q <= '0;
        end else begin
            gHist_q <= gHist_d;
            pathHist_q <= pathHist_d;
            u_reset_ctr_q <= u_reset_ctr_d;
            use_alt_on_na_q <= use_alt_on_na_d;
        end
    end
endmodule