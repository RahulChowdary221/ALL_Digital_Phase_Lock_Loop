# All-Digital Phase-Locked Loop (ADPLL) — Verilog RTL Implementation

![Language](https://img.shields.io/badge/language-Verilog-orange.svg)
![Tool](https://img.shields.io/badge/tool-Vivado%202022.2-green.svg)
![Board](https://img.shields.io/badge/board-Digilent%20ZedBoard%20Zynq--7000-red.svg)
![Status](https://img.shields.io/badge/status-Simulated%20%26%20Locked-brightgreen.svg)

---

## Table of Contents

- [Project Overview](#project-overview)
- [Why All-Digital — The DCO vs NCO Decision](#why-all-digital--the-dco-vs-nco-decision)
- [System Architecture](#system-architecture)
- [Module-by-Module Breakdown](#module-by-module-breakdown)
  - [Bang-Bang Phase Detector](#1-bang-bang-phase-detector-bbpd)
  - [Digital Loop Filter — PI Controller](#2-digital-loop-filter-dlf--pi-controller)
  - [Numerically Controlled Oscillator](#3-numerically-controlled-oscillator-nco)
  - [Clock Divider — Feedback Path](#4-clock-divider--feedback-path)
  - [Top-Level Structural Module](#5-top-level-structural-module)
- [Key Hardware Constraints and Engineering Decisions](#key-hardware-constraints-and-engineering-decisions)
- [Simulation and Verification](#simulation-and-verification)
- [Resource Utilisation](#resource-utilisation)
- [Repository Structure](#repository-structure)
- [How to Run in Vivado](#how-to-run-in-vivado)
- [Learning Journal](#learning-journal)
- [References](#references)

---

## Project Overview

This project is a complete RTL implementation of an **All-Digital Phase-Locked Loop (ADPLL)** written in Verilog, synthesised and verified in **Xilinx Vivado 2022.2** targeting the **Digilent ZedBoard (Zynq-7000 xc7z020clg484-1)**.

A Phase-Locked Loop is a closed-loop feedback control system that synchronises an output clock to a reference clock — locking both frequency and phase. Unlike traditional analog PLLs that rely on voltage-controlled oscillators and RC filters, this design is **entirely synchronous digital logic**: flip-flops, adders, and multiplexers. No analog components, no ring oscillators, no routing-dependent delay chains.

**Target behaviour:** Given a 100 MHz system clock and a 20 MHz reference input, the ADPLL locks its output clock to 20 MHz and maintains phase alignment indefinitely.

### Specifications

| Parameter | Value |
|---|---|
| System Clock (`sys_clk`) | 100 MHz |
| Reference Clock (`ref_clk`) | 20 MHz |
| Locked Output (`clk_out`) | 20 MHz |
| Phase Accumulator Width | 32 bits |
| Frequency Resolution | ~0.023 Hz |
| Phase Detector Type | Bang-Bang (binary decision) |
| Loop Filter Type | Proportional-Integral (PI) |
| Oscillator Type | NCO — Phase Accumulator + MSB tap |
| Multipliers Used | **Zero** — multiplier-free design |
| HDL | Verilog (RTL level) |
| Simulation Tool | Vivado XSim |

---

## Why All-Digital — The DCO vs NCO Decision

When implementing a PLL on an FPGA, the most critical architectural decision is how to build the oscillator. Two approaches exist:

**DCO (Digitally Controlled Oscillator)** physically changes gate propagation delays to alter the clock period. It relies on ring oscillators and tap-selectable delay chains inside the FPGA fabric. The result: routing-dependent timing, temperature drift, and synthesis warnings. Vivado cannot reliably time-close a DCO because the delays depend on silicon placement, not logic.

**NCO (Numerically Controlled Oscillator)** never touches the master crystal clock. A digital phase accumulator increments by a Frequency Control Word (FCW) on every clock cycle. When the accumulator overflows past `2^N`, the MSB toggles — generating the output frequency entirely through arithmetic. The formula is:

```
fout = (FCW / 2^N) × fmaster
```

An NCO is pure synchronous RTL — flip-flops and a single adder. Vivado synthesises it trivially, timing closure is guaranteed, and frequency resolution is set by the accumulator width, not by analog component tolerances.

**This project uses an NCO exclusively.** The DCO approach was deliberately rejected for FPGA implementation.

---

## System Architecture

The ADPLL is a closed feedback loop of four independent RTL modules wired together in a structural top module.

```
                   ┌──────────────────────────────────────────────────┐
                   │                   ADPLL_top                      │
                   │                                                  │
  ref_clk  ───────►│──► Bang-Bang PD ──► Loop Filter ──► NCO ────────►│──► clk_out
                   │       (BBPD)          (DLF/PI)                   │
                   │          ▲                                        │
                   │          │         feedback_trace                 │
                   │          └──────── ÷N Divider ◄──────────────────│
                   │                  (clk_divider)                   │
                   └──────────────────────────────────────────────────┘
```

**Signal flow:**

1. BBPD compares `ref_clk` against the divided feedback clock → outputs `phase_error` (+1 or −1)
2. DLF processes `phase_error` through a PI controller → outputs 32-bit `tuning_word`
3. NCO accumulates `tuning_word` every `sys_clk` cycle → outputs `clk_out` via MSB tap
4. `clk_out` feeds back through the ÷N divider → re-enters BBPD to close the loop

Lock is achieved when `phase_error` rapidly alternates ±1 every few cycles — the standard steady-state of a Bang-Bang topology.

---

## Module-by-Module Breakdown

### 1. Bang-Bang Phase Detector (`Bang_Bang_PD.v`)

**Concept:** A traditional two-flip-flop PFD encodes phase error in pulse *width* — a continuous time-domain quantity. Processing this in a digital filter requires a Time-to-Digital Converter (TDC), one of the hardest blocks to implement on FPGAs due to routing delay unpredictability. The Bang-Bang PD eliminates the TDC entirely by asking a single binary question on every `ref_clk` rising edge:

> *"Is the NCO clock currently HIGH or LOW?"*

- NCO clock is **LOW** at the `ref_clk` edge → NCO is lagging → output `+1` (speed up)
- NCO clock is **HIGH** at the `ref_clk` edge → NCO is leading → output `−1` (slow down)

The output is pure discrete math that the loop filter can process directly.

**Metastability protection:** Because `ref_clk` and `nco_clk` are asynchronous clock domains, a **2-stage synchroniser** (two flip-flops in series using non-blocking `<=` assignments, both clocked by `ref_clk`) safely crosses the domain boundary before the binary decision is made.

**Port interface:**

```verilog
module Bang_Bang_PD (
    input  wire              clk,         // ref_clk — triggers the sample
    input  wire              nco_clk,     // NCO output to be sampled
    input  wire              rst,         // Synchronous active-high reset
    output reg signed [1:0]  phase_error  // +1 (2'b01) or -1 (2'b11)
);
```

**Two's complement encoding:**

| Condition | Binary | Signed Decimal |
|---|---|---|
| NCO lagging (speed up) | `2'b01` | +1 |
| NCO leading (slow down) | `2'b11` | −1 |
| Reset / no error | `2'b00` | 0 |

---

### 2. Digital Loop Filter (`DLF.v`) — PI Controller

**Concept:** Replaces the analog RC low-pass filter of a traditional PLL. Implements a discrete-time Proportional-Integral (PI) controller that converts the binary ±1 phase error into a smooth, stable 32-bit tuning word for the NCO.

**Governing equations:**

```
P[n]  = Kp × e[n]
I[n]  = I[n-1] + Ki × e[n]
Mout  = M_center + P[n] + I[n]
```

**Critical hardware optimisation — multiplier-free design:**

Because the BBPD restricts `e[n]` to exactly {+1, 0, −1}, the multiplications reduce to:

```
e[n] = +1  →  add Kp      /  add Ki to accumulator
e[n] = −1  →  subtract Kp /  subtract Ki from accumulator
e[n] =  0  →  hold state (no change)
```

No DSP48 multiplier blocks are instantiated. The entire PI controller synthesises to LUTs and carry-chain adders.

**Architecture split:**

| Path | Hardware Type | Verilog Construct |
|---|---|---|
| Proportional `P[n]` | Combinational MUX | `always @(*)` with `=` |
| Integral `I[n]` | Sequential accumulator | `always @(posedge clk)` with `<=` |
| Output sum `Mout` | Combinational adder | `assign` |

**Tuned parameters:**

```verilog
parameter signed [31:0] KP       = 500_000;
parameter signed [31:0] KI       = 10_000;
parameter signed [31:0] M_CENTER = 858_993_459;  // Baseline tuning word for 20 MHz output
```

> **Why such large gain values?** The 32-bit accumulator counts to 4.29 billion. A Kp of 50 shifts the tuning word by 0.0001% — invisible to the NCO. Gains must be scaled proportionally to the accumulator depth to produce a meaningful frequency correction within observable simulation time.

---

### 3. Numerically Controlled Oscillator (`Nco.v`)

**Concept:** On every `sys_clk` rising edge, the FCW is added to a 32-bit phase accumulator register. When the accumulator overflows past `2^32`, it wraps back to zero — this is not a bug, it is the mechanism. The MSB toggles at a rate proportional to FCW, generating the output clock.

```
fout = (FCW / 2^32) × fmaster
```

**Frequency resolution at 100 MHz:**

```
Δf = 100 MHz / 2^32  ≈  0.023 Hz
```

**Port interface:**

```verilog
module Nco (
    input  wire        clk,          // 100 MHz system clock
    input  wire        rst,          // Synchronous active-high reset
    input  wire [31:0] tuning_word,  // FCW from the loop filter
    output wire        clk_out       // MSB of accumulator = output clock
);
```

**Core RTL — the entire oscillator in three lines:**

```verilog
always @(posedge clk)
    phase_accumulator <= rst ? 32'b0 : phase_accumulator + tuning_word;

assign clk_out = phase_accumulator[31];
```

---

### 4. Clock Divider — Feedback Path (`clk_divider.v`)

A parameterisable divide-by-N counter placed in the feedback path. When `clk_out` is divided by N before re-entering the BBPD, the loop is forced to lock `clk_out` at `N × ref_clk`, making the ADPLL a programmable frequency multiplier.

```verilog
parameter div_value = 4;  // Sets the division factor
```

For a direct 1:1 lock (`fout = fref`), the divider is bypassed and `clk_out` feeds directly back to the BBPD.

---

### 5. Top-Level Structural Module (`ADPLL_top.v`)

Pure structural Verilog — no behavioural logic, only wire declarations and named-port module instantiations. This mirrors professional VLSI netlisting practice where the top module is a clean interconnect description.

**Internal connecting wires:**

```verilog
wire signed [1:0] error_trace;    // BBPD output  →  DLF input
wire [31:0]       tuning_trace;   // DLF output   →  NCO input
wire              feedback_trace; // NCO output   →  ÷N  →  BBPD input
```

**Named port mapping example:**

```verilog
DLF #(
    .KP      (500_000),
    .KI      (10_000),
    .M_center(858_993_459)
) u_dlf (
    .clk   (ref_clk),
    .rst   (rst),
    .error (error_trace),
    .out   (tuning_trace)
);
```

---

## Key Hardware Constraints and Engineering Decisions

### The Gain Scaling Problem — "Drop in the Ocean"
Early simulation with `Kp = 50, Ki = 50` produced a 5000 ns hunting cycle with no convergence. Root cause: adding 50 to a 32-bit tuning word of ~42 million shifts the NCO frequency by 11 Hz out of 1 MHz — a 0.001% perturbation. The NCO cannot react fast enough to correct phase within observable time. Gains were scaled to 500,000 / 10,000 to produce corrections in the kHz range, achieving lock within microseconds.

### Nyquist Limit Violation
Initial testbench: `sys_clk = 100 MHz`, `ref_clk = 10 MHz`, `÷N = 10`. This required the NCO to output 100 MHz — identical to the system clock, violating the Nyquist limit (practical NCO output ceiling is ~40% of `fmaster`). The loop filter drove the tuning word toward 4.29 billion and the system never converged. Solution: reconfigured to `÷N = 2`, `ref_clk = 20 MHz`, with `M_center` recomputed for a 20 MHz baseline.

### Phase Quantization Jitter — An Unavoidable Physical Limit
The locked waveform shows `clk_out` edges that straddle the reference clock edge rather than sitting perfectly on it. In a synchronous digital system, `clk_out` can only transition on a `sys_clk` edge — creating a rigid 10 ns time grid. The result is a peak-to-peak jitter of exactly 1 UI (10 ns) — the theoretical minimum for this architecture. This is not a code bug; it is the fundamental resolution limit of synchronous logic, analogous to quantisation noise in an ADC.

### Integrator Amnesia Bug
An early version of DLF included `In <= 0` in the zero-error `else` branch. This reset the integral accumulator every time the loop momentarily reached lock, causing the NCO to snap back to baseline and immediately lose lock. Fix: remove the `else` branch entirely. An unaddressed flip-flop holds its state — which is exactly correct integrator behaviour.

### Bang-Bang Limit Cycling is Normal
In steady state, `phase_error` will never sit at zero. The BBPD always outputs +1 or −1 because the clocks will always have some residual phase offset at the sampling instant. Rapid ±1 alternation every few cycles is the correct locked state, not a malfunction.

---

## Simulation and Verification

**Testbench clock configuration (`tb_adpll_top.v`):**

```verilog
always #5    sys_clk = ~sys_clk;  // 100 MHz  (10 ns period)
always #25   ref_clk = ~ref_clk;  // 20 MHz   (50 ns period)
```

**Verification steps in Vivado XSim:**

1. Set runtime to at least **100 µs** — use **Run All (F3)**, not the default 1 µs
2. In the Scope panel click `uut` and add these signals to the waveform viewer:
   - `error_trace` → right-click → Radix → **Signed Decimal** (shows +1 / −1, not 1 / 3)
   - `tuning_trace` → right-click → Radix → **Unsigned Decimal** (shows FCW convergence)
3. Zoom to the 50–100 µs region to observe steady-state behaviour

**Expected waveform behaviour:**

| Signal | Before Lock | After Lock |
|---|---|---|
| `tuning_trace` | Ramping up or down | Stable near 858,993,459 |
| `error_trace` | Long +1 or −1 plateaus | Rapid ±1 alternation every few cycles |
| `clk_out` | Frequency drifting | Stable 20 MHz, edges tracking `ref_clk` |

**Waveform screenshots:**

> Replace the lines below with your actual Vivado screenshots once captured:
>
> ```markdown
> ![Locked Waveform](images/waveform_locked.png)
> ![RTL Schematic](images/rtl_schematic.png)
> ```

---

## Resource Utilisation

Estimated post-synthesis on xc7z020clg484-1 (Zynq-7000):

| Resource | Used | Available | Utilisation |
|---|---|---|---|
| Slice LUTs | ~45 | 53,200 | < 0.1% |
| Flip-Flops (FFs) | ~70 | 106,400 | < 0.1% |
| DSP Blocks | **0** | 220 | **0%** |
| BUFG Clock Buffers | 2 | 32 | 6% |
| Block RAM | 0 | 140 | 0% |

> Zero DSP blocks is a direct result of the multiplier-free PI controller design made possible by the Bang-Bang detector's ±1 output constraint.

---

## Repository Structure

```
ALL_Digital_Phase_Lock_Loop/
│
├── src/
│   ├── Bang_Bang_PD.v        # Phase detector — 2-stage synchroniser + binary decision
│   ├── DLF.v                 # Digital loop filter — multiplier-free PI controller
│   ├── Nco.v                 # NCO — 32-bit phase accumulator + MSB tap
│   ├── clk_divider.v         # Parameterisable ÷N feedback divider
│   └── ADPLL_top.v           # Structural top module — pure instantiation, no logic
│
├── sim/
│   └── tb_adpll_top.v        # System-level closed-loop testbench
│
├── images/
│   ├── rtl_schematic.png     # Vivado RTL elaboration schematic
│   └── waveform_locked.png   # XSim waveform showing lock condition
│
└── README.md
```

---

## How to Run in Vivado

**Step 1 — Create a new RTL project**
```
File → Project → New → RTL Project
Target part: xc7z020clg484-1
```

**Step 2 — Add design sources**

Add all `.v` files from `src/` as Design Sources. Set `ADPLL_top.v` as the Top Module.

**Step 3 — Add simulation source**

Add `sim/tb_adpll_top.v` as a Simulation Source only.

**Step 4 — Run Behavioral Simulation**
```
Flow Navigator → Simulation → Run Behavioral Simulation
```

In the XSim toolbar click **Run All (F3)**. The loop needs at least 50 µs to converge — do not use the default 1 µs run time.

**Step 5 — Observe the lock**

Add `error_trace` (Signed Decimal) and `tuning_trace` (Unsigned Decimal) to the waveform window. Zoom to the 50–100 µs region. A locked system shows `error_trace` alternating ±1 rapidly and `tuning_trace` stable near 858,993,459.

---

## Learning Journal

This project was built from first principles — starting from the question *"what even is a clock signal?"* and arriving at a working closed-loop digital control system. These are the genuine realisations from the process:

**On choosing Bang-Bang over a traditional PFD:** A standard PFD encodes phase error in pulse width — a continuous time quantity that a digital multiplier cannot process. Solving this properly needs a TDC, which is one of the hardest circuits on FPGAs due to routing delay unpredictability. The Bang-Bang PD sidesteps this entirely by reducing the measurement to one binary sample per reference edge. The tradeoff is that steady-state error can never be zero — the system always limit-cycles ±1. That is a property of the architecture, not a failure.

**On gain scaling:** The instinct is "small gains equal stability." In a 32-bit NCO system, a gain of 50 changes a 4.29-billion-count accumulator by 0.001% — the correction is physically invisible to the NCO. Gains must be proportional to the state space of the system being controlled, not to human intuition about what sounds like a small number.

**On the Nyquist violation:** The initial testbench asked the NCO to generate 100 MHz from a 100 MHz system clock. The loop never converged and the reason was not obvious. Tracing the math from M_center through the divider ratio to the actual target frequency revealed the reference was physically unreachable — the NCO was being asked to run at 100% of its clock source. Theory without hardware arithmetic is incomplete.

**On quantization jitter:** A perfect digital lock does not look like a perfect analog lock. The edges will always straddle the time grid defined by the system clock. This is not a bug — it is the fundamental resolution limit of synchronous logic, directly analogous to quantisation noise in an ADC. Escaping the grid requires a faster system clock.

**On the integrator:** Resetting the integral accumulator to zero when error is zero feels safe but destroys the system. The integrator's job is to remember the frequency offset it learned over time. If it resets when error momentarily touches zero, the loop crashes immediately after locking. An unaddressed register holds its state — that silence is the correct behaviour.

---

## References

- B. Razavi, *Design of Analog CMOS Integrated Circuits*, McGraw-Hill
- R.E. Best, *Phase-Locked Loops: Design, Simulation, and Applications*, McGraw-Hill
- Xilinx UG901 — Vivado Design Suite: HDL Synthesis Guide
- HDLBits — Verilog Practice: [https://hdlbits.01xz.net](https://hdlbits.01xz.net)

