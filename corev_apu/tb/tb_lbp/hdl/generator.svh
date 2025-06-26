/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

class Generator #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_update_t = logic,
    parameter type bht_prediction_t = logic,
    parameter type bp_metadata_t = logic,
    parameter MIN_N_STREAMS = 6,
    parameter MAX_N_STREAMS = 12,
    parameter MIN_STREAM_LEN = 7,
    parameter MAX_STREAM_LEN = 12,
    parameter P_COMPRESSED_INSTR = 50,
    parameter P_NOT_A_BRANCH = 75,
    parameter P_FORWARD_BRANCH = 50,
    parameter P_FORWARD_TAKEN = 50,
    parameter P_BACKWARD_TAKEN = 90
);
    InstructionStream #(
        .CVA6Cfg(CVA6Cfg),
        .bht_prediction_t(bht_prediction_t),
        .bht_update_t(bht_update_t),
        .P_COMPRESSED_INSTR(P_COMPRESSED_INSTR),
        .P_NOT_A_BRANCH(P_NOT_A_BRANCH),
        .P_FORWARD_BRANCH(P_FORWARD_BRANCH),
        .P_FORWARD_TAKEN(P_FORWARD_TAKEN),
        .P_BACKWARD_TAKEN(P_BACKWARD_TAKEN)
    ) streams [];

    InstructionStream #(
        .CVA6Cfg(CVA6Cfg),
        .bht_prediction_t(bht_prediction_t),
        .bht_update_t(bht_update_t),
        .P_COMPRESSED_INSTR(P_COMPRESSED_INSTR),
        .P_NOT_A_BRANCH(P_NOT_A_BRANCH),
        .P_FORWARD_BRANCH(P_FORWARD_BRANCH),
        .P_FORWARD_TAKEN(P_FORWARD_TAKEN),
        .P_BACKWARD_TAKEN(P_BACKWARD_TAKEN)
    ) selected_stream;

    longint unsigned start_addresses [$];
    longint unsigned stream_lengths [$];
    int nstreams;

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
        Transaction #(
            .CVA6Cfg(CVA6Cfg),
            .bht_update_t(bht_update_t),
            .bht_prediction_t(bht_prediction_t),
            .bp_metadata_t(bp_metadata_t)
        ) trans;

        trans = get_transaction(instr, bht_update);
        drv_mbx.put(trans);
        @(drv_done);
        bht_prediction = trans.bht_prediction_o[trans.vpc_i[$clog2(CVA6Cfg.INSTR_PER_FETCH):1]];
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
        // Step 1. Choose the number of instruction streams
        void'(std::randomize(nstreams) with {
            nstreams inside {[MIN_N_STREAMS:MAX_N_STREAMS]};
        });

        // Step 2. Create each instruction stream with their lengths
        streams = new [nstreams];
        for (int i = 0; i < nstreams; i++) begin
            int stream_length;
            longint unsigned start_addr;
            longint unsigned end_addr;

            void'(std::randomize(stream_length) with {
                stream_length inside {[MIN_STREAM_LEN:MAX_STREAM_LEN]};
            });
            void'(std::randomize(start_addr) with {
                foreach (start_addresses[ii])
                    start_addr != start_addresses[ii];
                !(start_addr % 4);
            });
            stream_lengths[$+1] = stream_length;
            start_addresses[$+1] = start_addr;
            streams[i] = new;
            void'(streams[i].create(null, stream_length, start_addr));
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

    function automatic Transaction #(
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
        Transaction #(
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

endclass : Generator