/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

class GeneratorFrontend #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter NR_ENTRIES = 1024,
    parameter MIN_N_BLOCKS = 5,
    parameter MAX_N_BLOCKS = 10,
    parameter MIN_BLOCK_LEN = 20,
    parameter MAX_BLOCK_LEN = 50,
    parameter MIN_N_STREAMS = 6,
    parameter MAX_N_STREAMS = 12,
    parameter MIN_STREAM_LEN = 7,
    parameter MAX_STREAM_LEN = 12,
    parameter P_NOT_A_BRANCH = 75,
    parameter P_CONDITIONAL = 50,
    parameter P_COND_TAKEN = 50,
    parameter P_LOOP_TAKEN = 90,
    parameter P_COMPRESSED_INSTR = 50
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

    InstructionStream #(
        .CVA6Cfg(CVA6Cfg),
        .bht_prediction_t(bht_prediction_t),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(NR_ENTRIES),
        .P_COMPRESSED_INSTR(P_COMPRESSED_INSTR),
        .P_NOT_A_BRANCH(P_NOT_A_BRANCH),
        .P_CONDITIONAL(P_CONDITIONAL),
        .P_COND_TAKEN(P_COND_TAKEN),
        .P_LOOP_TAKEN(P_LOOP_TAKEN)
    ) streams [];

    InstructionStream #(
        .CVA6Cfg(CVA6Cfg),
        .bht_prediction_t(bht_prediction_t),
        .bht_update_t(bht_update_t),
        .NR_ENTRIES(NR_ENTRIES),
        .P_COMPRESSED_INSTR(P_COMPRESSED_INSTR),
        .P_NOT_A_BRANCH(P_NOT_A_BRANCH),
        .P_CONDITIONAL(P_CONDITIONAL),
        .P_COND_TAKEN(P_COND_TAKEN),
        .P_LOOP_TAKEN(P_LOOP_TAKEN)
    ) selected_stream;

    int start_blocks [$], block_lengths [$];
    longint unsigned start_addresses [$];
    longint unsigned stream_lengths [$];
    int nstreams, nblocks;

    mailbox drv_mbx;
    event drv_done;
    int ncycles;

    function automatic new(
        int ncycles,
        mailbox drv_mbx,
        ref event drv_done
    );
        this.drv_mbx = drv_mbx;
        this.ncycles = ncycles;
        this.drv_done = drv_done;
        create_streams();
    endfunction : new

    task run();
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr;
        bht_update_t bht_update;
        bht_prediction_t bht_prediction;
        bit cf_path, mispredict;

        bht_prediction = '0;
        bht_update = '0;
        mispredict = 0;
        cf_path = 0;
        for (int i = 0; i < ncycles; i++) begin
            $display ("T=%0t [Generator] Loop: %0d/%0d create next transaction", $time, i+1, ncycles);

            // Generate output
            instr = get_next_instruction();
            gen_output(instr, bht_update, bht_prediction, cf_path);

            // Generate update
            gen_update(instr, bht_prediction, cf_path, bht_update, mispredict);

            // Check for mispredicts
            if (mispredict) begin
                selected_stream.flush_instr_queue();
                void'(change_ctrl_flow(instr, bit'(bht_update.valid), bit'(bht_update.taken)));
            end
        end
        $display ("T=%0t [Generator] Done generation of %0d items", $time, ncycles);
    endtask : run

    task automatic gen_output(
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr,
        bht_update_t bht_update,
        ref bht_prediction_t bht_prediction,
        bit cf_path
    );
        TransactionFrontend #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t),
            .bp_metadata_t(bp_metadata_t)
        ) trans;

        trans = get_transaction(instr, bht_update);
        drv_mbx.put(trans);
        @(drv_done);
        bht_prediction = trans.bht_prediction_o[$clog2(CVA6Cfg.INSTR_PER_FETCH):1];
        cf_path = change_ctrl_flow(instr, bit'(bht_prediction.valid), bit'(bht_prediction.taken));
    endtask : gen_output

    task automatic gen_update(
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr,
        bht_prediction_t bht_prediction,
        bit cf_path,
        ref bht_update_t bht_update,
        bit is_mispredict
    );
        bht_update.valid = instr.is_branch();
        bht_update.pc = instr.get_vpc();
        bht_update.taken = is_taken(instr);
        bht_update.metadata = bht_prediction.metadata;
        is_mispredict = (bht_update.valid) && (cf_path != bht_update.taken);
    endtask : gen_update

    function automatic void create_streams();
        int start_block, block_length;
        int stream_length;

        let are_disjoint(la, ua, lb, ub) = (ua < lb) || (la > ub);

        // Step 1.1: Randomly select blocks in [MIN_BLOCKS...MAX_BLOCKS]
        void'(std::randomize(nblocks) with {
            nblocks inside {[MIN_N_BLOCKS:MAX_N_BLOCKS]};
        });
        //$display("NBLOCK = %d\n", nblocks);

        // Step 1.2: Randomly select blocks and their lengths
        assert (MAX_STREAM_LEN <= MIN_BLOCK_LEN)
            else $error("MAX_STREAM_LEN must be smaller than MIN_BLOCK_LEN");
        for (int i = 0; i < nblocks; i++) begin
            void'(std::randomize(start_block, block_length) with {
                start_block inside {[0:NR_ROWS-1]};
                block_length inside {[MIN_BLOCK_LEN:MAX_BLOCK_LEN]};
                start_block+block_length > start_block;
                start_block+block_length inside {[0:NR_ROWS-1]};
                foreach (start_blocks[ii])
                    are_disjoint(start_block, start_block+block_length-1,
                        start_blocks[ii], start_blocks[ii] + block_lengths[ii]-1);
            });
            start_blocks[$+1] = start_block;
            block_lengths[$+1] = block_length;
            //$display("BLOCK RANGE %d = [%x..%x]", i, start_block, start_block+block_length-1);
        end

        // Step 2. Choose the number of instruction streams
        void'(std::randomize(nstreams) with {
            nstreams inside {[MIN_N_STREAMS:MAX_N_STREAMS]};
        });
        //$display("NSTREAMS = %d", nstreams);

        // Step 3. Create each instruction stream with their lengths
        streams = new [nstreams];
        for (int i = 0; i < nstreams; i++) begin
            longint unsigned start_addr;
            int idx;
            void'(std::randomize(idx) with {
                idx inside {[0:nblocks-1]};
            });
            //$display("IDX = %d", idx);

            void'(std::randomize(stream_length) with {
                stream_length inside {[MIN_STREAM_LEN:MAX_STREAM_LEN]};
            });
            void'(std::randomize(start_addr) with {
                foreach (start_addresses[ii])
                    start_addr != start_addresses[ii];
                start_addr[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET] inside {[start_blocks[idx]:start_blocks[idx]+block_lengths[idx]-1-stream_length]};
                !(start_addr % 4);
            });
            stream_lengths[$+1] = stream_length;
            start_addresses[$+1] = start_addr;
            //$display("Stream %d length = %d\nSTART_BLOCK = %x\n", i, stream_length, start_addr[PREDICTION_BITS-1:ROW_ADDR_BITS+OFFSET]);
            streams[i] = new(start_blocks, block_lengths, nblocks);
            void'(streams[i].create(null, stream_length, start_addr));
            //streams[i].print();
        end
    endfunction : create_streams

    function automatic void  select_stream();
        static int idx;
        void'(std::randomize(idx) with {
            idx inside {[0:nstreams-1]};
            idx != const'(idx);
        });
        $display("IDX = %d\n", idx);
        selected_stream = streams[idx];
    endfunction : select_stream

    function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) get_next_instruction();
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr;
        if (selected_stream == null) begin
            select_stream();
        end
        instr = selected_stream.get_next_instruction(0);
        if (instr == null) begin
            select_stream();
            instr = selected_stream.get_next_instruction(1);
        end
        return instr;
    endfunction : get_next_instruction

    function automatic bit is_taken(
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr
    );
        return selected_stream.is_taken(instr);
    endfunction : is_taken

    function automatic TransactionFrontend #(
        .CVA6Cfg(CVA6Cfg),
        .bht_update_t(bht_update_t),
        .bht_prediction_t(bht_prediction_t),
        .bp_metadata_t(bp_metadata_t)
    ) get_transaction (
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr,
        bht_update_t bht_update
    );
        TransactionFrontend #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t),
            .bp_metadata_t(bp_metadata_t)
        ) trans = new;

        trans.vpc_i = instr.get_vpc();
        trans.bht_update_i = bht_update;
        return trans;
    endfunction : get_transaction

    function bit change_ctrl_flow (
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr,
        bit valid,
        bit taken
    );
        return selected_stream.change_ctrl_flow(instr, valid, taken);
    endfunction : change_ctrl_flow

endclass : GeneratorFrontend