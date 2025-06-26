/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 23/03/25
 */

class InstructionStream #(
    parameter config_pkg::cva6_cfg_t CVA6Cfg = config_pkg::cva6_cfg_empty,
    parameter type bht_prediction_t = logic,
    parameter type bht_update_t = logic,
    parameter P_COMPRESSED_INSTR = 50,
    parameter P_NOT_A_BRANCH = 75,
    parameter P_FORWARD_BRANCH = 50,
    parameter P_FORWARD_TAKEN = 50,
    parameter P_BACKWARD_TAKEN = 90
);
    local AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) stream;

    local AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) q [$];

    function automatic new();

    endfunction : new

    function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) create (
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) stream_i = null,
        longint unsigned stream_length = 21,
        longint unsigned start_addr = 'h12340000,
        bit recursive = 0
    );
        static logic [CVA6Cfg.VLEN-1:0] g_vpc [$];
        automatic logic [CVA6Cfg.VLEN-1:0] vpc [$];
        static logic [CVA6Cfg.VLEN-1:0] target_addresses [$];
        static Instruction #(
            .CVA6Cfg(CVA6Cfg)
        ) previous_instrs [logic [CVA6Cfg.VLEN-1:0]];
        automatic AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) current_instr;
        automatic NormalInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) norm_instr;
        automatic ExitInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) exit_instr;

        assert (stream_length >= 2);

        // Create the first instruction of the stream
        norm_instr = new(start_addr);
        norm_instr.set_rvc(0);
        if (!recursive) begin
            stream = norm_instr;
        end else begin
            stream_i = norm_instr;
        end
        current_instr = norm_instr;
        vpc[$+1] = start_addr;
        g_vpc[$+1] = start_addr;
        previous_instrs[g_vpc[$]] = norm_instr;

        // Create the other instructions
        vpc[$+1] = start_addr + 4;
        g_vpc[$+1] = start_addr + 4;
        target_addresses[$+1] = -1; // Dummy
        for (int i = 1; i < stream_length - 1; i++) begin
            automatic int p_not_a_branch;
            automatic int p_forward;
            automatic int p_compressed_instr;
            automatic bit rvc;
            automatic logic [CVA6Cfg.VLEN-1:0] target_address;

            void'(std::randomize(p_not_a_branch) with {
                p_not_a_branch inside {[0:100]};
            });
            void'(std::randomize(p_forward) with {
                p_forward inside {[0:100]};
            });
            void'(std::randomize(p_compressed_instr) with {
                p_compressed_instr inside {[0:100]};
            });
            rvc = p_compressed_instr < P_COMPRESSED_INSTR;
            if (p_not_a_branch < P_NOT_A_BRANCH) begin
                automatic NormalInstruction #(
                    .CVA6Cfg(CVA6Cfg)
                ) norm_instr;
                norm_instr = new(vpc[$]);
                current_instr.setNextInstr(norm_instr);
                previous_instrs[g_vpc[$]] = norm_instr;
            end else begin
                if (p_forward < P_FORWARD_BRANCH) begin
                    automatic ForwardBranchInstruction #(
                        .CVA6Cfg(CVA6Cfg)
                    ) forward_branch_instr;
                    automatic AbstractInstruction #(
                        .CVA6Cfg(CVA6Cfg)
                    ) target_instr;
                    forward_branch_instr = new(vpc[$]);
                    void'(std::randomize(target_address) with {
                        !(target_address inside {target_addresses[0:$]});
                        !(target_address % 4);
                    });
                    target_addresses[$+1] = target_address;
                    previous_instrs[g_vpc[$]] = forward_branch_instr;
                    forward_branch_instr.set_target_address(target_address);
                    current_instr.setNextInstr(forward_branch_instr);
                    target_instr = create(target_instr, stream_length - i, target_address, 1);
                    assert(target_instr != null)
                    else $fatal("Target instruction should NOT be null");
                    forward_branch_instr.set_target_instr(target_instr);
                    assert(forward_branch_instr.get_target_instr() != null)
                    else $fatal("Target instruction should NOT be null");
                end else begin
                    automatic BackwardBranchInstruction #(
                        .CVA6Cfg(CVA6Cfg)
                    ) backward_branch_instr;
                    backward_branch_instr = new(vpc[$]);
                    void'(std::randomize(target_address) with {
                        target_address inside {g_vpc[0:$]};
                    });
                    previous_instrs[g_vpc[$]] = backward_branch_instr;
                    backward_branch_instr.set_target_address(target_address);
                    backward_branch_instr.set_target_instr(previous_instrs[target_address]);
                    current_instr.setNextInstr(backward_branch_instr);
                end
            end
            vpc[$+1] = vpc[$] + (rvc ? 2 : 4);
            g_vpc[$+1] = vpc[$];
            current_instr = current_instr.getNextInstr();
            current_instr.set_rvc(rvc);
        end
        // Create the last instruction of the stream
        exit_instr = new(vpc[$]);
        exit_instr.set_rvc(0);
        current_instr.setNextInstr(exit_instr);

        g_vpc = g_vpc[0:$-stream_length];

        return stream_i;
    endfunction : create

    function automatic void flush_instr_queue ();
        q = {};
    endfunction : flush_instr_queue

    function automatic AbstractInstruction #(
        .CVA6Cfg(CVA6Cfg)
    ) get_next_instruction (
        bit first_call
    );
        automatic AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr;

        if (first_call)
            q.push_back(stream);

        if (q.size() > 0) begin
            instr = q.pop_front();
            return instr;
        end
        return null;
    endfunction

    function automatic is_taken(
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr
    );
        if (instr.is_branch()) begin
            int p_taken;
            void'(std::randomize(p_taken) with {
                p_taken inside {[0:100]};
            });
            return (instr.is_forward_branch() ? (p_taken < P_FORWARD_TAKEN) : (p_taken < P_BACKWARD_TAKEN));
        end else
            return 0;
    endfunction : is_taken

    function automatic bit change_ctrl_flow (
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr,
        bit valid,
        bit taken
    );
        if (!instr.is_branch() || !valid || !taken) begin
            if (instr.getNextInstr() != null)
                q.push_front(instr.getNextInstr()); // PC + 4
            return 0;
        end
        if (instr.is_forward_branch()) begin
            if (instr.getNextInstr() != null) begin
                q.push_back(instr.getNextInstr());  // PC + 4
            end
            if (instr.get_target_instr() != null) begin
                q.push_front(instr.get_target_instr()); // Target address
            end
        end else begin
            flush_instr_queue();
            if (instr.get_target_instr() != null) begin
                q.push_front(instr.get_target_instr()); // Target address
            end
        end
        return 1;
    endfunction

    function automatic void print(
        AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) stream_i = null,
        string tab = "",
        bit recursive = 0
    );
        automatic AbstractInstruction #(
            .CVA6Cfg(CVA6Cfg)
        ) instr;

        if (!recursive) begin
            instr = stream;
        end else begin
            instr = stream_i;
        end
        while (instr) begin
            instr.print(tab);
            if (instr.is_branch() && instr.is_forward_branch())
                print(instr.get_target_instr(), {tab, "\t"}, 1);
            instr = instr.getNextInstr();
        end
    endfunction : print
endclass : InstructionStream