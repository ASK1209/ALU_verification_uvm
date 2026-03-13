# 8-Bit ALU Verification using UVM (Universal Verification Methodology)

A complete functional verification project for an 8-bit ALU using a UVM Testbench with constrained-random stimulus, a scoreboard, functional coverage, and SVA assertions. Simulated on **Aldec Riviera-PRO 2025.04** via [EDA Playground](https://www.edaplayground.com/).

---

## Project Structure

```
├── alu.sv          # RTL: 8-bit ALU design
└── alu_tb.sv       # UVM Testbench: Interface, Seq Item, Sequences, Driver,
                    #                Monitor, Scoreboard, Coverage, Assertions
```

---

## Design Overview

The DUT is a synchronous 8-bit ALU with the following interface:

| Port            | Direction | Description                          |
|-----------------|-----------|--------------------------------------|
| `clk`           | Input     | Clock signal                         |
| `rst`           | Input     | Active-high synchronous reset        |
| `a`             | Input     | 8-bit operand A                      |
| `b`             | Input     | 8-bit operand B                      |
| `opcode`        | Input     | 4-bit operation select               |
| `result`        | Output    | 8-bit operation result               |
| `zero_flag`     | Output    | High when result is `0`              |
| `carry_flag`    | Output    | Carry/borrow out                     |
| `overflow_flag` | Output    | Signed overflow flag                 |

**Supported Operations:**

| Opcode     | Operation | Expression     |
|------------|-----------|----------------|
| `4'b0000`  | ADD       | `a + b`        |
| `4'b0001`  | SUB       | `a - b`        |
| `4'b0010`  | AND       | `a & b`        |
| `4'b0011`  | OR        | `a \| b`       |
| `4'b0100`  | XOR       | `a ^ b`        |
| `4'b0101`  | NOT       | `~a`           |
| `4'b0110`  | NAND      | `~(a & b)`     |
| `4'b0111`  | NOR       | `~(a \| b)`    |
| `4'b1000`  | SHL       | `a << 1`       |
| `4'b1001`  | SHR       | `a >> 1`       |

---

## Testbench Architecture

```
┌─────────────────────────────────────────────────────┐
│                      alu_test                       │
│  ┌──────────────────────────────────────────────┐   │
│  │                   alu_env                    │   │
│  │  ┌─────────────────────────────────────┐     │   │
│  │  │             alu_agent               │     │   │
│  │  │  ┌────────────┐   ┌─────────────┐  │     │   │
│  │  │  │alu_sequencer│  │ alu_driver  │──┼─────┼──► DUT
│  │  │  └────────────┘   └─────────────┘  │     │
│  │  │  ┌─────────────────────────────┐   │     │
│  │  │  │       alu_monitor           │◄──┼─────┼─── DUT
│  │  │  └──────────────┬──────────────┘   │     │
│  │  └─────────────────┼─────────────────-┘     │
│  │            analysis_port                     │
│  │  ┌──────────────────▼──────────────────┐     │
│  │  │          alu_scoreboard              │     │
│  │  └──────────────────────────────────────┘     │
│  └──────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
```

### Components

| Component        | Description |
|------------------|-------------|
| **alu_seq_item** | Sequence item holding `a`, `b`, `opcode` (stimulus) and `result`, flags (response) |
| **alu_rand_seq** | Generates 50 constrained-random transactions across all opcodes |
| **alu_corner_seq** | Directed sequence — all opcodes × boundary values `{0x00, 0xFF}` |
| **alu_all_ops_seq** | Sweeps all 10 opcodes with 10 random transactions each |
| **alu_driver**   | Drives stimulus onto the DUT via virtual interface on `negedge clk` |
| **alu_monitor**  | Observes DUT outputs on `posedge clk` and sends transactions to scoreboard |
| **alu_scoreboard** | Built-in reference model — computes expected result and all flags, compares against DUT |
| **alu_agent**    | Bundles driver, monitor, and sequencer; exports analysis port |
| **alu_env**      | Instantiates agent and scoreboard; connects analysis port |
| **alu_test**     | Top-level test — runs corner, all-ops, and random sequences in order |

---

## Functional Coverage

Coverage is collected using a covergroup `alu_cg` instantiated in the top module, sampled automatically on `@(posedge clk)`:

| Coverpoint            | Description                                           |
|-----------------------|-------------------------------------------------------|
| `cp_opcode`           | Covers all 10 operations (ADD through SHR)            |
| `cp_a`                | Covers `zero`, `max`, `low [0x01–0x7F]`, `high [0x80–0xFE]` |
| `cp_b`                | Covers `zero`, `max`, `low [0x01–0x7F]`, `high [0x80–0xFE]` |
| `cp_zero_flag`        | Covers `zero_flag = 0` and `1`                        |
| `cp_carry_flag`       | Covers `carry_flag = 0` and `1`                       |
| `cp_overflow_flag`    | Covers `overflow_flag = 0` and `1`                    |
| `cx_opcode_zero`      | Cross of `cp_opcode` and `cp_zero_flag`               |
| `cx_opcode_carry`     | Cross of `cp_opcode` and `cp_carry_flag`              |
| `cx_opcode_a`         | Cross of `cp_opcode` and `cp_a`                       |
| `cx_opcode_b`         | Cross of `cp_opcode` and `cp_b`                       |

**Unreachable bins excluded using `ignore_bins`:**

| Excluded Combination | Reason |
|----------------------|--------|
| `carry=1` for AND / OR / XOR / NOT / NAND / NOR | These operations never produce a carry output |
| `zero=1, overflow=1` (any carry) | Signed overflow always produces a non-zero result |

**Result: 100% Functional Coverage achieved**

---

## SVA Assertions

| Assertion          | Property Verified                                              |
|--------------------|----------------------------------------------------------------|
| `A_RESET_RESULT`   | When `rst=1`, `result` must be `0`                            |
| `A_RESET_FLAGS`    | When `rst=1`, all flags must be `0`                           |
| `A_ZERO_FLAG`      | `zero_flag` correctly equals `(result == 0)`                  |
| `A_ADD_CARRY`      | ADD with both MSBs = 1 must assert `carry_flag`               |
| `A_SUB_EQUAL`      | SUB with `a == b` must give `result=0` and `zero_flag=1`      |
| `A_NOT`            | NOT result must equal `~a`                                    |
| `A_NAND`           | NAND result must equal `~(a & b)`                             |
| `A_NOR`            | NOR result must equal `~(a \| b)`                             |
| `A_SHL_LSB`        | SHL result LSB must always be `0`                             |
| `A_SHL_CARRY`      | SHL `carry_flag` must equal MSB of previous `a`               |
| `A_SHR_MSB`        | SHR result MSB must always be `0`                             |
| `A_SHR_CARRY`      | SHR `carry_flag` must equal LSB of previous `a`               |
| `A_AND_OR_REL`     | AND result must always be a bitwise subset of OR result       |
| `A_XOR_SELF`       | XOR with `a == b` must always produce `0`                     |
| `A_OR_ONES`        | OR with a `0xFF` operand must always produce `0xFF`           |

**Result: All 15 assertions passed — zero failures**

---

## Simulation Results

```
=========================================
         SCOREBOARD SUMMARY
=========================================
  ADD     PASS: 19     FAIL: 0
  SUB     PASS: 21     FAIL: 0
  AND     PASS: 18     FAIL: 0
  OR      PASS: 20     FAIL: 0
  XOR     PASS: 17     FAIL: 0
  NOT     PASS: 19     FAIL: 0
  NAND    PASS: 18     FAIL: 0
  NOR     PASS: 20     FAIL: 0
  SHL     PASS: 19     FAIL: 0
  SHR     PASS: 21     FAIL: 0
-----------------------------------------
  TOTAL PASS = 192    TOTAL FAIL = 0
=========================================
      *** ALL TESTS PASSED ***

=========================================
       FUNCTIONAL COVERAGE SUMMARY
=========================================
  Overall    Coverage = 100.00 %
  Opcode     Coverage = 100.00 %
  A-input    Coverage = 100.00 %
  B-input    Coverage = 100.00 %
  Zero-flag  Coverage = 100.00 %
  Carry-flag Coverage = 100.00 %
  OVF-flag   Coverage = 100.00 %
  Cross OpcodeXZero   = 100.00 %
  Cross OpcodeXCarry  = 100.00 %
  Cross OpcodeXA      = 100.00 %
  Cross OpcodeXB      = 100.00 %
=========================================

Assertions: No failures (15/15 passed)
```

---

## How to Run

### On EDA Playground
1. Go to [https://www.edaplayground.com](https://www.edaplayground.com)
2. Paste `alu.sv` in the **Design** pane
3. Paste `alu_tb.sv` in the **Testbench** pane
4. Select **Aldec Riviera-PRO** as the simulator
5. Add `-sv -uvm` in the **Compile Options** box
6. Add `+access+r +UVM_TESTNAME=alu_test` in the **Run Options** box
7. Click **Run**

---

## Tools Used

| Tool       | Version / Detail                    |
|------------|-------------------------------------|
| Simulator  | Aldec Riviera-PRO 2025.04           |
| Language   | SystemVerilog + UVM 1.2 (IEEE 1800-2012) |
| Platform   | EDA Playground                      |

---

## Key Concepts Demonstrated

- Full UVM layered testbench architecture (sequence item, sequence, driver, monitor, agent, env, test)
- Interface-based stimulus delivery using `virtual interface`
- Constrained-random stimulus using `rand`, `randomize()`, and `constraint` blocks
- Multiple directed sequences for corner case and opcode sweep coverage
- Self-checking scoreboard with a built-in SystemVerilog reference model
- Functional coverage with covergroups, bins, cross coverage, and `ignore_bins` for unreachable states
- SystemVerilog Assertions (SVA) — 15 `assert property` + 15 matching `cover property` checks
- `uvm_config_db` for virtual interface propagation
- Per-opcode pass/fail tracking and end-of-simulation summary reporting

---

## 👩‍💻 Author

**Ahalya Sivakumar**  
Design Verification Engineer  
SystemVerilog | Assertions | Functional Coverage | UVM (Learning)
LinkedIn: linkedin.com/in/yourprofile
```
