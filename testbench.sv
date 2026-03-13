// ============================================================
// 8-bit ALU - UVM Testbench (Single File)
// Simulator : Aldec Riviera-PRO
// Compile   : -sv -uvm
// Run       : +access+r +UVM_TESTNAME=alu_test
// Opcodes   : 0=ADD 1=SUB 2=AND 3=OR 4=XOR 5=NOT
//             6=NAND 7=NOR 8=SHL 9=SHR
// ============================================================

`include "uvm_macros.svh"
import uvm_pkg::*;

// ============================================================
// INTERFACE
// ============================================================
interface alu_if(input logic clk);
    logic        rst;
    logic [7:0]  a;
    logic [7:0]  b;
    logic [3:0]  opcode;
    logic [7:0]  result;
    logic        zero_flag;
    logic        carry_flag;
    logic        overflow_flag;
endinterface

// ============================================================
// SEQUENCE ITEM
// ============================================================
class alu_seq_item extends uvm_sequence_item;

    `uvm_object_utils(alu_seq_item)

    // Stimulus
    rand logic [7:0] a;
    rand logic [7:0] b;
    rand logic [3:0] opcode;

    // Response
    logic [7:0] result;
    logic       zero_flag;
    logic       carry_flag;
    logic       overflow_flag;

    // Only valid opcodes 0-9
    constraint opcode_dist_c {
        opcode inside {[4'b0000 : 4'b1001]};
    }

    // Hit all opcodes equally
    constraint opcode_uniform_c {
        opcode dist {
            4'b0000 := 10,  // ADD
            4'b0001 := 10,  // SUB
            4'b0010 := 10,  // AND
            4'b0011 := 10,  // OR
            4'b0100 := 10,  // XOR
            4'b0101 := 10,  // NOT
            4'b0110 := 10,  // NAND
            4'b0111 := 10,  // NOR
            4'b1000 := 10,  // SHL
            4'b1001 := 10   // SHR
        };
    }

    // Corner case bias for operands
    constraint corner_cases_c {
        a dist {8'h00 := 5, 8'hFF := 5, [8'h01:8'hFE] := 90};
        b dist {8'h00 := 5, 8'hFF := 5, [8'h01:8'hFE] := 90};
    }

    function new(string name = "alu_seq_item");
        super.new(name);
    endfunction

    function string convert2string();
        return $sformatf("opcode=%04b a=%08b(%0d) b=%08b(%0d) | result=%08b(%0d) zero=%b carry=%b overflow=%b",
                          opcode, a, a, b, b, result, result,
                          zero_flag, carry_flag, overflow_flag);
    endfunction

endclass

// ============================================================
// SEQUENCES
// ============================================================

// ---- Base Sequence ----
class alu_base_seq extends uvm_sequence #(alu_seq_item);
    `uvm_object_utils(alu_base_seq)
    function new(string name = "alu_base_seq");
        super.new(name);
    endfunction
endclass

// ---- Random Sequence ----
class alu_rand_seq extends alu_base_seq;

    `uvm_object_utils(alu_rand_seq)

    int unsigned num_transactions = 1000;

    function new(string name = "alu_rand_seq");
        super.new(name);
    endfunction

    task body();
        alu_seq_item tr;
        #30; // Wait for reset deassertion
        repeat(num_transactions) begin
            tr = alu_seq_item::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize()) else
                `uvm_fatal("SEQ", "Randomization failed")
            finish_item(tr);
        end
    endtask

endclass

// ---- Corner Case Sequence ----
class alu_corner_seq extends alu_base_seq;

    `uvm_object_utils(alu_corner_seq)

    function new(string name = "alu_corner_seq");
        super.new(name);
    endfunction

    task body();
        alu_seq_item tr;
        // Test every opcode with max/min boundary values
        for (int op = 0; op <= 9; op++) begin
            // a=FF, b=FF
            tr = alu_seq_item::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with { opcode == op; a == 8'hFF; b == 8'hFF; })
                else `uvm_fatal("SEQ","Corner randomize failed");
            finish_item(tr);
            // a=00, b=00
            tr = alu_seq_item::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with { opcode == op; a == 8'h00; b == 8'h00; })
                else `uvm_fatal("SEQ","Corner randomize failed");
            finish_item(tr);
            // a=FF, b=00
            tr = alu_seq_item::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with { opcode == op; a == 8'hFF; b == 8'h00; })
                else `uvm_fatal("SEQ","Corner randomize failed");
            finish_item(tr);
            // a=00, b=FF
            tr = alu_seq_item::type_id::create("tr");
            start_item(tr);
            assert(tr.randomize() with { opcode == op; a == 8'h00; b == 8'hFF; })
                else `uvm_fatal("SEQ","Corner randomize failed");
            finish_item(tr);
        end
    endtask

endclass

// ---- All Opcodes Sequence ----
class alu_all_ops_seq extends alu_base_seq;

    `uvm_object_utils(alu_all_ops_seq)

    function new(string name = "alu_all_ops_seq");
        super.new(name);
    endfunction

    task body();
        alu_seq_item tr;
        for (int op = 0; op <= 9; op++) begin
            repeat (10) begin
                tr = alu_seq_item::type_id::create("tr");
                start_item(tr);
                assert(tr.randomize() with { opcode == op; })
                    else `uvm_fatal("SEQ", "Randomize failed");
                finish_item(tr);
            end
        end
    endtask

endclass

// ============================================================
// DRIVER
// ============================================================
class alu_driver extends uvm_driver #(alu_seq_item);

    `uvm_component_utils(alu_driver)

    virtual alu_if vif;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
            `uvm_fatal("DRV", "Could not get virtual interface from config db")
    endfunction

    task run_phase(uvm_phase phase);
        alu_seq_item tr;
        // Initialize signals
        vif.a      <= 8'h00;
        vif.b      <= 8'h00;
        vif.opcode <= 4'h0;
        forever begin
            seq_item_port.get_next_item(tr);
            @(negedge vif.clk);
            vif.a      <= tr.a;
            vif.b      <= tr.b;
            vif.opcode <= tr.opcode;

            seq_item_port.item_done();
        end
    endtask

endclass

// ============================================================
// MONITOR
// ============================================================
class alu_monitor extends uvm_monitor;

    `uvm_component_utils(alu_monitor)

    virtual alu_if vif;
    uvm_analysis_port #(alu_seq_item) mon_ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        mon_ap = new("mon_ap", this);
        if (!uvm_config_db #(virtual alu_if)::get(this, "", "vif", vif))
            `uvm_fatal("MON", "Could not get virtual interface from config db")
    endfunction

    task run_phase(uvm_phase phase);
        alu_seq_item tr;
        // Skip reset period
        @(negedge vif.rst);
        forever begin
            @(posedge vif.clk);
            #1; // Small delay to let outputs settle
            if (!vif.rst) begin
                tr               = alu_seq_item::type_id::create("tr");
                tr.a             = vif.a;
                tr.b             = vif.b;
                tr.opcode        = vif.opcode;
                tr.result        = vif.result;
                tr.zero_flag     = vif.zero_flag;
                tr.carry_flag    = vif.carry_flag;
                tr.overflow_flag = vif.overflow_flag;

                mon_ap.write(tr);
            end
        end
    endtask

endclass

// ============================================================
// SCOREBOARD  (Reference Model + Checker)
// ============================================================
class alu_scoreboard extends uvm_scoreboard;

    `uvm_component_utils(alu_scoreboard)

    uvm_analysis_imp #(alu_seq_item, alu_scoreboard) sb_imp;

    // Global counters
    int pass_count;
    int fail_count;

    // Per-opcode pass/fail tracking
    int opcode_pass[10];
    int opcode_fail[10];

    // Opcode names for reporting
    string op_names[10] = '{"ADD","SUB","AND","OR ","XOR","NOT","NAND","NOR ","SHL","SHR"};

    function new(string name, uvm_component parent);
        super.new(name, parent);
        pass_count = 0;
        fail_count = 0;
        foreach (opcode_pass[i]) opcode_pass[i] = 0;
        foreach (opcode_fail[i]) opcode_fail[i] = 0;
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        sb_imp = new("sb_imp", this);
    endfunction

    // ---- Reference Model ----
    function void write(alu_seq_item tr);
        logic [7:0]  expected_result;
        logic        expected_zero;
        logic        expected_carry;
        logic        expected_overflow;
        logic [8:0]  temp;

        expected_carry    = 1'b0;
        expected_overflow = 1'b0;
        temp              = 9'b0;

        case (tr.opcode)
            4'b0000: begin // ADD
                temp              = {1'b0, tr.a} + {1'b0, tr.b};
                expected_result   = temp[7:0];
                expected_carry    = temp[8];
                expected_overflow = (~tr.a[7] & ~tr.b[7] &  temp[7]) |
                                    ( tr.a[7] &  tr.b[7] & ~temp[7]);
            end
            4'b0001: begin // SUB
                temp              = {1'b0, tr.a} - {1'b0, tr.b};
                expected_result   = temp[7:0];
                expected_carry    = temp[8];
                expected_overflow = (~tr.a[7] &  tr.b[7] &  temp[7]) |
                                    ( tr.a[7] & ~tr.b[7] & ~temp[7]);
            end
            4'b0010: expected_result = tr.a & tr.b;   // AND
            4'b0011: expected_result = tr.a | tr.b;   // OR
            4'b0100: expected_result = tr.a ^ tr.b;   // XOR
            4'b0101: expected_result = ~tr.a;          // NOT
            4'b0110: expected_result = ~(tr.a & tr.b); // NAND
            4'b0111: expected_result = ~(tr.a | tr.b); // NOR
            4'b1000: begin // SHL
                expected_result = {tr.a[6:0], 1'b0};
                expected_carry  = tr.a[7];
            end
            4'b1001: begin // SHR
                expected_result = {1'b0, tr.a[7:1]};
                expected_carry  = tr.a[0];
            end
            default: expected_result = 8'b0;
        endcase

        expected_zero = (expected_result == 8'b0);

        // ---- Checker ----
        if (tr.result        !== expected_result   ||
            tr.zero_flag     !== expected_zero     ||
            tr.carry_flag    !== expected_carry    ||
            tr.overflow_flag !== expected_overflow) begin

            `uvm_error("SB", $sformatf(
                "MISMATCH! opcode=%04b(%s) a=%0d b=%0d | Result: Got=%0d Exp=%0d | Zero: Got=%b Exp=%b | Carry: Got=%b Exp=%b | OVF: Got=%b Exp=%b",
                tr.opcode, op_names[tr.opcode], tr.a, tr.b,
                tr.result,        expected_result,
                tr.zero_flag,     expected_zero,
                tr.carry_flag,    expected_carry,
                tr.overflow_flag, expected_overflow))
            fail_count++;
            if (tr.opcode <= 9) opcode_fail[tr.opcode]++;
        end else begin

            pass_count++;
            if (tr.opcode <= 9) opcode_pass[tr.opcode]++;
        end
    endfunction

    // ---- Report ----
    function void report_phase(uvm_phase phase);
        `uvm_info("SB", "=========================================", UVM_NONE)
        `uvm_info("SB", "         SCOREBOARD SUMMARY              ", UVM_NONE)
        `uvm_info("SB", "=========================================", UVM_NONE)
        `uvm_info("SB", $sformatf("  %-6s  PASS: %-5s  FAIL: %-5s", "OPCODE","COUNT","COUNT"), UVM_NONE)
        `uvm_info("SB", "-----------------------------------------", UVM_NONE)
        for (int i = 0; i < 10; i++) begin
            `uvm_info("SB", $sformatf("  %-6s  PASS: %-5d  FAIL: %-5d",
                       op_names[i], opcode_pass[i], opcode_fail[i]), UVM_NONE)
        end
        `uvm_info("SB", "-----------------------------------------", UVM_NONE)
        `uvm_info("SB", $sformatf("  TOTAL PASS = %0d", pass_count), UVM_NONE)
        `uvm_info("SB", $sformatf("  TOTAL FAIL = %0d", fail_count), UVM_NONE)
        `uvm_info("SB", "=========================================", UVM_NONE)
        if (fail_count == 0)
            `uvm_info("SB",  "      *** ALL TESTS PASSED ***          ", UVM_NONE)
        else
            `uvm_error("SB", "      *** TESTS FAILED ***              ")
    endfunction

endclass

// ============================================================
// AGENT
// ============================================================
class alu_agent extends uvm_agent;

    `uvm_component_utils(alu_agent)

    alu_driver                    drv;
    alu_monitor                   mon;
    uvm_sequencer #(alu_seq_item) seqr;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        drv  = alu_driver::type_id::create("drv",  this);
        mon  = alu_monitor::type_id::create("mon",  this);
        seqr = uvm_sequencer #(alu_seq_item)::type_id::create("seqr", this);
    endfunction

    function void connect_phase(uvm_phase phase);
        drv.seq_item_port.connect(seqr.seq_item_export);
    endfunction

endclass

// ============================================================
// ENVIRONMENT
// ============================================================
class alu_env extends uvm_env;

    `uvm_component_utils(alu_env)

    alu_agent      agent;
    alu_scoreboard sb;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        agent = alu_agent::type_id::create("agent", this);
        sb    = alu_scoreboard::type_id::create("sb",    this);
    endfunction

    function void connect_phase(uvm_phase phase);
        agent.mon.mon_ap.connect(sb.sb_imp);
    endfunction

endclass

// ============================================================
// TEST
// ============================================================
class alu_test extends uvm_test;

    `uvm_component_utils(alu_test)

    alu_env        env;
    alu_rand_seq   rand_seq;
    alu_corner_seq corner_seq;
    alu_all_ops_seq all_ops_seq;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        env = alu_env::type_id::create("env", this);
    endfunction

    task run_phase(uvm_phase phase);
        phase.raise_objection(this);

        // 1. Corner cases first
        `uvm_info("TEST", "==> Starting Corner Case Sequence", UVM_NONE)
        corner_seq = alu_corner_seq::type_id::create("corner_seq");
        corner_seq.start(env.agent.seqr);

        // 2. All opcodes sweep
        `uvm_info("TEST", "==> Starting All-Ops Sequence", UVM_NONE)
        all_ops_seq = alu_all_ops_seq::type_id::create("all_ops_seq");
        all_ops_seq.start(env.agent.seqr);

        // 3. Main random sequence
        `uvm_info("TEST", "==> Starting Random Sequence (200 transactions)", UVM_NONE)
        rand_seq = alu_rand_seq::type_id::create("rand_seq");
        rand_seq.num_transactions = 50;
        rand_seq.start(env.agent.seqr);

        `uvm_info("TEST", "==> All sequences complete", UVM_NONE)
        #50;
        phase.drop_objection(this);
    endtask

    function void report_phase(uvm_phase phase);
        `uvm_info("TEST", "ALU UVM Test Complete", UVM_NONE)
    endfunction

endclass

// ============================================================
// TOP MODULE
// ============================================================
module tb;

    import uvm_pkg::*;
    `include "uvm_macros.svh"

    // -------------------------------------------------------
    // Clock & Interface
    // -------------------------------------------------------
    logic clk;
    initial clk = 0;
    always #5 clk = ~clk;

    alu_if vif(clk);

    // -------------------------------------------------------
    // DUT
    // -------------------------------------------------------
    alu dut (
        .clk          (clk),
        .rst          (vif.rst),
        .a            (vif.a),
        .b            (vif.b),
        .opcode       (vif.opcode),
        .result       (vif.result),
        .zero_flag    (vif.zero_flag),
        .carry_flag   (vif.carry_flag),
        .overflow_flag(vif.overflow_flag)
    );

    // -------------------------------------------------------
    // SVA Assertions
    // -------------------------------------------------------

    // P1: During reset, result must be 0
    property p_reset_clears_result;
        @(posedge clk) vif.rst |-> (vif.result == 8'b0);
    endproperty
    A_RESET_RESULT: assert property(p_reset_clears_result)
        else $error("[ASSERT FAIL] P1: Reset did not clear result. result=%0h", vif.result);
    C_RESET_RESULT: cover property(p_reset_clears_result);

    // P2: During reset, all flags must be 0
    property p_reset_clears_flags;
        @(posedge clk) vif.rst |->
            (vif.zero_flag == 0 && vif.carry_flag == 0 && vif.overflow_flag == 0);
    endproperty
    A_RESET_FLAGS: assert property(p_reset_clears_flags)
        else $error("[ASSERT FAIL] P2: Reset did not clear flags");
    C_RESET_FLAGS: cover property(p_reset_clears_flags) ;

    // P3: Zero flag must equal (result == 0), one cycle after any non-reset op
    property p_zero_flag_correct;
        @(posedge clk) (!vif.rst) |-> ((vif.result == 8'b0) ? (vif.zero_flag == 1'b1) : (vif.zero_flag == 1'b0));
    endproperty
    A_ZERO_FLAG: assert property(p_zero_flag_correct)
        else $error("[ASSERT FAIL] P3: Zero flag mismatch. result=%0h zero_flag=%b",
                    vif.result, vif.zero_flag);
    C_ZERO_FLAG: cover property(p_zero_flag_correct) ;

    // P4: ADD with both MSBs = 1 must produce carry = 1
    property p_add_carry;
        @(posedge clk)
            (!vif.rst && $past(vif.opcode) == 4'b0000 &&
             $past(vif.a[7]) == 1'b1  && $past(vif.b[7]) == 1'b1)
            |-> (vif.carry_flag == 1'b1);
    endproperty
    A_ADD_CARRY: assert property(p_add_carry)
        else $error("[ASSERT FAIL] P4: ADD carry not set when both MSBs=1");
    C_ADD_CARRY: cover property(p_add_carry) ;

    // P5: SUB a==b must give result=0 and zero_flag=1
    property p_sub_equal_zero;
        @(posedge clk)
            (!vif.rst && $past(vif.opcode) == 4'b0001 &&
             $past(vif.a) == $past(vif.b))
            |-> (vif.result == 8'b0 && vif.zero_flag == 1'b1);
    endproperty
    A_SUB_EQUAL: assert property(p_sub_equal_zero)
        else $error("[ASSERT FAIL] P5: SUB a==b did not give zero result");
    C_SUB_EQUAL: cover property(p_sub_equal_zero) ;

    // P6: NOT result must equal ~a (combinational, registered one cycle later)
    property p_not_correct;
        @(posedge clk) (!vif.rst && $past(vif.opcode) == 4'b0101)
            |-> (vif.result == ~$past(vif.a));
    endproperty
    A_NOT: assert property(p_not_correct)
        else $error("[ASSERT FAIL] P6: NOT result incorrect. Got=%0h Exp=%0h",
                    vif.result, ~$past(vif.a));
    C_NOT: cover property(p_not_correct) ;

    // P7: NAND result must equal ~(a & b)
    property p_nand_correct;
        @(posedge clk) (!vif.rst && $past(vif.opcode) == 4'b0110)
            |-> (vif.result == ~($past(vif.a) & $past(vif.b)));
    endproperty
    A_NAND: assert property(p_nand_correct)
        else $error("[ASSERT FAIL] P7: NAND result incorrect");
    C_NAND: cover property(p_nand_correct) ;

    // P8: NOR result must equal ~(a | b)
    property p_nor_correct;
        @(posedge clk) (!vif.rst && $past(vif.opcode) == 4'b0111)
            |-> (vif.result == ~($past(vif.a) | $past(vif.b)));
    endproperty
    A_NOR: assert property(p_nor_correct)
        else $error("[ASSERT FAIL] P8: NOR result incorrect");
    C_NOR: cover property(p_nor_correct) ;

    // P9: SHL — LSB of result must always be 0
    property p_shl_lsb_zero;
        @(posedge clk) (!vif.rst && $past(vif.opcode) == 4'b1000)
            |-> (vif.result[0] == 1'b0);
    endproperty
    A_SHL_LSB: assert property(p_shl_lsb_zero)
        else $error("[ASSERT FAIL] P9: SHL LSB not 0. result=%08b", vif.result);
    C_SHL_LSB: cover property(p_shl_lsb_zero) ;

    // P10: SHL carry must equal MSB of previous a
    property p_shl_carry;
        @(posedge clk) (!vif.rst && $past(vif.opcode) == 4'b1000)
            |-> (vif.carry_flag == $past(vif.a[7]));
    endproperty
    A_SHL_CARRY: assert property(p_shl_carry)
        else $error("[ASSERT FAIL] P10: SHL carry mismatch");
    C_SHL_CARRY: cover property(p_shl_carry) ;

    // P11: SHR — MSB of result must always be 0
    property p_shr_msb_zero;
        @(posedge clk) (!vif.rst && $past(vif.opcode) == 4'b1001)
            |-> (vif.result[7] == 1'b0);
    endproperty
    A_SHR_MSB: assert property(p_shr_msb_zero)
        else $error("[ASSERT FAIL] P11: SHR MSB not 0. result=%08b", vif.result);
    C_SHR_MSB: cover property(p_shr_msb_zero) ;

    // P12: SHR carry must equal LSB of previous a
    property p_shr_carry;
        @(posedge clk) (!vif.rst && $past(vif.opcode) == 4'b1001)
            |-> (vif.carry_flag == $past(vif.a[0]));
    endproperty
    A_SHR_CARRY: assert property(p_shr_carry)
        else $error("[ASSERT FAIL] P12: SHR carry mismatch");
    C_SHR_CARRY: cover property(p_shr_carry) ;

    // P13: AND result must be a subset of OR result (AND ⊆ OR)
    property p_and_subset_of_or;
        @(posedge clk) (!vif.rst && $past(vif.opcode) == 4'b0010)
            |-> ((vif.result & ($past(vif.a) | $past(vif.b))) == vif.result);
    endproperty
    A_AND_OR_REL: assert property(p_and_subset_of_or)
        else $error("[ASSERT FAIL] P13: AND result not subset of OR");
    C_AND_OR_REL: cover property(p_and_subset_of_or) ;

    // P14: XOR with a==b must always give 0
    property p_xor_self_zero;
        @(posedge clk)
            (!vif.rst && $past(vif.opcode) == 4'b0100 &&
             $past(vif.a) == $past(vif.b))
            |-> (vif.result == 8'b0);
    endproperty
    A_XOR_SELF: assert property(p_xor_self_zero)
        else $error("[ASSERT FAIL] P14: XOR a==b did not produce 0");
    C_XOR_SELF: cover property(p_xor_self_zero) ;

    // P15: OR with all-ones operand must give all-ones result
    property p_or_ones;
        @(posedge clk)
            (!vif.rst && $past(vif.opcode) == 4'b0011 &&
             ($past(vif.a) == 8'hFF || $past(vif.b) == 8'hFF))
            |-> (vif.result == 8'hFF);
    endproperty
    A_OR_ONES: assert property(p_or_ones)
        else $error("[ASSERT FAIL] P15: OR with 0xFF did not give 0xFF");
    C_OR_ONES: cover property(p_or_ones) ;

    // -------------------------------------------------------
    // Functional Coverage
    // -------------------------------------------------------
    covergroup alu_cg @(posedge clk);
        option.per_instance = 1;
        option.comment      = "ALU Functional Coverage";

        // All 10 opcodes
        cp_opcode : coverpoint vif.opcode {
            bins ADD  = {4'b0000};
            bins SUB  = {4'b0001};
            bins AND  = {4'b0010};
            bins OR   = {4'b0011};
            bins XOR  = {4'b0100};
            bins NOT  = {4'b0101};
            bins NAND = {4'b0110};
            bins NOR  = {4'b0111};
            bins SHL  = {4'b1000};
            bins SHR  = {4'b1001};
        }

        // A operand ranges
        cp_a : coverpoint vif.a {
            bins zero = {8'h00};
            bins max  = {8'hFF};
            bins low  = {[8'h01 : 8'h7F]};
            bins high = {[8'h80 : 8'hFE]};
        }

        // B operand ranges
        cp_b : coverpoint vif.b {
            bins zero = {8'h00};
            bins max  = {8'hFF};
            bins low  = {[8'h01 : 8'h7F]};
            bins high = {[8'h80 : 8'hFE]};
        }

        // Flags
        cp_zero_flag     : coverpoint vif.zero_flag;
        cp_carry_flag    : coverpoint vif.carry_flag;
        cp_overflow_flag : coverpoint vif.overflow_flag;

        // Cross: opcode × zero flag
        cx_opcode_zero  : cross cp_opcode, cp_zero_flag;

        // Cross: opcode × carry flag
        // AND/OR/XOR/NOT/NAND/NOR never produce carry=1 — exclude those bins
        cx_opcode_carry : cross cp_opcode, cp_carry_flag {
            ignore_bins no_carry_and  = binsof(cp_opcode.AND)  && binsof(cp_carry_flag) intersect {1};
            ignore_bins no_carry_or   = binsof(cp_opcode.OR)   && binsof(cp_carry_flag) intersect {1};
            ignore_bins no_carry_xor  = binsof(cp_opcode.XOR)  && binsof(cp_carry_flag) intersect {1};
            ignore_bins no_carry_not  = binsof(cp_opcode.NOT)  && binsof(cp_carry_flag) intersect {1};
            ignore_bins no_carry_nand = binsof(cp_opcode.NAND) && binsof(cp_carry_flag) intersect {1};
            ignore_bins no_carry_nor  = binsof(cp_opcode.NOR)  && binsof(cp_carry_flag) intersect {1};
        }

        // Cross: opcode × a range
        cx_opcode_a     : cross cp_opcode, cp_a;

        // Cross: opcode × b range
        cx_opcode_b     : cross cp_opcode, cp_b;

        // Cross: all three flags (2x2x2=8 bins, 2 unreachable)
        // Reachable (6): z0c0o0, z1c0o0, z0c1o0, z0c0o1, z0c1o1, z1c1o0
        // Unreachable: overflow=1 requires signed wrap -> result != 0 -> zero must be 0
        //   z1c0o1 (zero=1,carry=0,ovf=1) - impossible
        //   z1c1o1 (zero=1,carry=1,ovf=1) - impossible
        /*cx_flags : cross cp_zero_flag, cp_carry_flag, cp_overflow_flag {
            ignore_bins z1_c0_o1 = binsof(cp_zero_flag) intersect {1} &&
                                   binsof(cp_carry_flag) intersect {0} &&
                                   binsof(cp_overflow_flag) intersect {1};
            ignore_bins z1_c1_o1 = binsof(cp_zero_flag) intersect {1} &&
                                   binsof(cp_carry_flag) intersect {1} &&
                                   binsof(cp_overflow_flag) intersect {1};
        }*/

    endgroup

    alu_cg cg1 = new();

    // -------------------------------------------------------
    // Reset & UVM Kickoff
    // -------------------------------------------------------
    initial begin
        uvm_config_db #(virtual alu_if)::set(null, "uvm_test_top.*", "vif", vif);
        // Suppress all UVM framework messages except errors/fatals
        uvm_top.set_report_verbosity_level_hier(UVM_NONE);
        run_test("alu_test");
    end

    initial begin
        vif.rst    = 1;
        vif.a      = 8'h00;
        vif.b      = 8'h00;
        vif.opcode = 4'h0;
        #20;
        vif.rst = 0;
    end

    // -------------------------------------------------------
    // Waveform Dump
    // -------------------------------------------------------
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);
    end

    // -------------------------------------------------------
    // Timeout Watchdog
    // -------------------------------------------------------
    initial begin
        #500_000;
        `uvm_fatal("TIMEOUT", "Simulation exceeded 500us — check for hangs")
    end

    // -------------------------------------------------------
    // Coverage Summary (runs after UVM completes)
    // -------------------------------------------------------
    final begin
        $display(" ");
        $display("=========================================");
        $display("       FUNCTIONAL COVERAGE SUMMARY       ");
        $display("=========================================");
        $display("  Overall    Coverage = %0.2f %%", cg1.get_coverage());
        $display("-----------------------------------------");
        $display("  Opcode     Coverage = %0.2f %%", cg1.cp_opcode.get_coverage());
        $display("  A-input    Coverage = %0.2f %%", cg1.cp_a.get_coverage());
        $display("  B-input    Coverage = %0.2f %%", cg1.cp_b.get_coverage());
        $display("  Zero-flag  Coverage = %0.2f %%", cg1.cp_zero_flag.get_coverage());
        $display("  Carry-flag Coverage = %0.2f %%", cg1.cp_carry_flag.get_coverage());
        $display("  OVF-flag   Coverage = %0.2f %%", cg1.cp_overflow_flag.get_coverage());
        $display("-----------------------------------------");
        $display("  Cross OpcodeXZero  = %0.2f %%", cg1.cx_opcode_zero.get_coverage());
        $display("  Cross OpcodeXCarry = %0.2f %%", cg1.cx_opcode_carry.get_coverage());
        $display("  Cross OpcodeXA     = %0.2f %%", cg1.cx_opcode_a.get_coverage());
      $display("  Cross OpcodeXB     = %0.2f %%", cg1.cx_opcode_b.get_coverage());
        //$display("  Cross All-Flags    = %0.2f %%", cg1.cx_flags.get_coverage());
        $display("=========================================");
    end

endmodule