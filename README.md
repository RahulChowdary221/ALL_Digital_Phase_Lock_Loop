# ALL_Digital_Phase_Lock_Loop
# All-Digital Phase-Locked Loop (ADPLL) in SystemVerilog

## 📌 Project Overview
This repository contains the complete RTL design and verification of an All-Digital Phase-Locked Loop (ADPLL). Unlike traditional analog PLLs, this system is completely digital, utilizing a multiplier-less Proportional-Integral (PI) controller and a discrete-time Numerically Controlled Oscillator (NCO) to achieve phase lock. 

This project was designed from the ground up to bridge the gap between theoretical Control Systems and physical VLSI hardware constraints.

## 🏗️ System Architecture
The ADPLL is constructed using three independent silicon blocks operating in a closed-loop feedback system:

1. **Bang-Bang Phase Detector (BBPD):**
   * Acts as the phase sensor.
   * Compares the reference clock (`ref_clk`) with the synthesized clock (`clk_out`).
   * Outputs a 2-bit signed error (`+1` for lagging, `-1` for leading).

2. **Digital Loop Filter (DLF) / PI Controller:**
   * Replaces the traditional analog RC low-pass filter.
   * **Hardware Optimization:** Completely multiplier-less design. Because the BBPD error is restricted to `+1` and `-1`, the Proportional ($K_p$) and Integral ($K_i$) paths are implemented using high-speed digital multiplexers and adders/subtractors.
   * Translates the phase error into a 32-bit tuning word.

3. **Numerically Controlled Oscillator (NCO):**
   * Driven by a high-speed system clock (100 MHz).
   * Uses a 32-bit phase accumulator. The Most Significant Bit (MSB) is extracted to generate the target frequency based on the tuning word.

## 🔬 Hardware Constraints & Learnings
During the design and simulation phases, several critical physical hardware limitations were addressed:

* **Control Theory vs. Silicon Scale (Gain Tuning):** Initial tuning with low $K_p$ and $K_i$ values resulted in massive limit cycling (5000ns hunting). The gains had to be mathematically scaled relative to the 32-bit accumulator ($2^{32}$) to provide enough "momentum" to shift the frequency within a reasonable lock time.
* **The Nyquist Limit in PLLs:** Attempting to lock a 100 MHz system clock to a 10 MHz reference via a Divide-by-10 feedback path violated sampling limits. The architecture was reconfigured to a Divide-by-2 feedback path, generating a stable 20 MHz output.
* **Phase Quantization Jitter & Truncation Spurs:** In a purely synchronous digital system, the phase can only shift in rigid time steps dictated by the system clock period (e.g., 10ns grid). The final locked waveform successfully demonstrated a Peak-to-Peak Jitter of exactly 1 Unit Interval (10ns), representing a mathematically perfect digital lock.

## 📊 Simulation & Verification
The system was verified using a Vivado top-level testbench.

* `sys_clk`: 100 MHz
* `ref_clk`: 20 MHz (Target)
* `clk_out`: 20 MHz (Locked Output)

**Waveform Analysis:**
The simulation proves that the ADPLL aggressively hunts the reference edge and maintains a stable lock, with the error trace rapidly limit-cycling between `+1` and `-1` (the standard operational state of a locked Bang-Bang topology).


