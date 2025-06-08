/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

`include "bht_frontend_if.svh"

package tb_pkg;
    typedef enum bit {
        JUMP, CONDITIONAL
    } branch_type;
    `include "transaction.svh"
    `include "abstract_instruction.svh"
    `include "transaction_frontend.svh"
    `include "exit_instruction.svh"
    `include "instruction.svh"
    `include "normal_instruction.svh"
    `include "branch_instruction.svh"
    `include "cond_branch_instruction.svh"
    `include "loop_branch_instruction.svh"
    `include "instr_stream.svh"
    `include "generator_frontend.svh"
    `include "driver_frontend.svh"
    `include "agent_frontend.svh"
    `include "environment.svh"
    `include "test.svh"
    `include "bht_shadow.svh"
endpackage