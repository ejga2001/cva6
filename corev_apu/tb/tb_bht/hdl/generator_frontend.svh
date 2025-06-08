/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

class GeneratorFrontend #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
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
    parameter P_LOOP_TAKEN = 90
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
        .NR_ENTRIES(NR_ENTRIES),
        .P_COMPRESSED_INSTR(50),
        .P_NOT_A_BRANCH(P_NOT_A_BRANCH),
        .P_CONDITIONAL(P_CONDITIONAL),
        .P_COND_TAKEN(P_COND_TAKEN),
        .P_LOOP_TAKEN(P_LOOP_TAKEN)
    ) streams [];

    InstructionStream #(
        .CVA6Cfg(CVA6Cfg),
        .NR_ENTRIES(NR_ENTRIES),
        .P_COMPRESSED_INSTR(50),
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
        TransactionFrontend #(
            .CVA6Cfg(CVA6Cfg)
        ) trans;
        for (int i = 0; i < ncycles; i++) begin
            trans = get_transaction();
            $display ("T=%0t [Generator] Loop: %0d/%0d create next transaction", $time, i+1, ncycles);
            drv_mbx.put(trans);
            @(drv_done);
        end
        $display ("T=%0t [Generator] Done generation of %0d items", $time, ncycles);
    endtask : run

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

    function automatic TransactionFrontend #(
        .CVA6Cfg(CVA6Cfg)
    ) get_transaction ();
        TransactionFrontend #(
            .CVA6Cfg(CVA6Cfg)
        ) trans;
        if (selected_stream == null) begin
            select_stream();
        end
        trans = selected_stream.get_transaction(0);
        if (trans == null) begin
            select_stream();
            trans = selected_stream.get_transaction(1);
        end
        return trans;
    endfunction : get_transaction

endclass : GeneratorFrontend