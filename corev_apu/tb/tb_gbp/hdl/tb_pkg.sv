/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

`include "bht_if.svh"

package tb_pkg;
    typedef enum bit {
        JUMP, CONDITIONAL
    } branch_type;
    `include "gbp_shadow.svh"
    `include "../../common_bpred_verif/abstract_instruction.svh"
    `include "transaction.svh"
    `include "../../common_bpred_verif/exit_instruction.svh"
    `include "../../common_bpred_verif/instruction.svh"
    `include "../../common_bpred_verif/normal_instruction.svh"
    `include "../../common_bpred_verif/branch_instruction.svh"
    `include "../../common_bpred_verif/forward_branch_instruction.svh"
    `include "../../common_bpred_verif/backward_branch_instruction.svh"
    `include "../../common_bpred_verif/instr_stream.svh"
    `include "generator.svh"
    `include "driver.svh"
    `include "monitor.svh"
    `include "scoreboard.svh"
    `include "agent.svh"
    `include "environment.svh"
    `include "test.svh"
endpackage