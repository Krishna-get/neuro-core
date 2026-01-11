# Hyperbolic CORDIC Exponential Accelerator

![Language](https://img.shields.io/badge/Language-Verilog-blue)
![Status](https://img.shields.io/badge/Status-Verified-green)

A high-precision, multiplier-less hardware accelerator for the exponential function ($e^x$) implemented in Verilog. 

This core is designed using the **Hyperbolic CORDIC algorithm** and is specifically optimized for the input range $[-1, 0]$. It is intended for use in neuromorphic computing applications, specifically for handling exponential decay in **Spike-Timing-Dependent Plasticity (STDP)** weight updates.

## 🚀 Key Features

* **Algorithm:** Hyperbolic CORDIC (Vectoring Mode) with $3k+1$ iteration repetition.
* **Precision:** 64-bit Signed Fixed-Point (`S1.23.40`).
    * *Resolution:* $2^{-40} \approx 9.09 \times 10^{-13}$.
* **Optimized Architecture:** "Direct Core" design removes the need for argument reduction overhead for the $[-1, 0]$ range.
* **High Efficiency:** * **0** DSP Slices (Multiplier-less).
    * **45 Cycles** Latency (Deterministic).
* **Accuracy:** Absolute error $< 1.2 \times 10^{-4}$ (Calibrated).
