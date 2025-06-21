/*
 * Copyright (c) 2025. All rights reserved.
 * Created by enrique, 22/03/25
 */

`include "bht_if.svh"

package tb_pkg;
    typedef enum bit {
        JUMP, CONDITIONAL
    } branch_type;
    `include "bht_shadow.svh"
    `include "abstract_instruction.svh"
    `include "transaction.svh"
    `include "exit_instruction.svh"
    `include "instruction.svh"
    `include "normal_instruction.svh"
    `include "branch_instruction.svh"
    `include "cond_branch_instruction.svh"
    `include "loop_branch_instruction.svh"
    `include "instr_stream.svh"
    `include "generator.svh"
    `include "driver.svh"
    `include "monitor.svh"
    `include "scoreboard.svh"
    `include "agent.svh"
    `include "environment.svh"
    `include "test.svh"
endpackage