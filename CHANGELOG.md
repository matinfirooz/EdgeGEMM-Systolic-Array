# Changelog

## 2.0.1 — Hardware schematic figures

- Redrew the full accelerator and PE with conventional RTL register, mux, multiplier/adder and bus symbols.
- Added detailed operand banking/read qualification and widened affine quantization schematics.
- Added vector PDF exports, a figure gallery and signal/symbol notes.
- Preserved the RTL, testbenches, vectors and captured verification evidence.

## 2.0.0 — Modular banked core

- Factored the original four-module design into 16 reusable, synthesizable components.
- Added a separate enhanced core with rectangular shapes, K_MAX depth, double-buffered operands/configuration, valid tokens, pauses and protected ownership.
- Added exact zero-product hold with a disabled-mode ablation and event counters.
- Added result snapshotting and stable ready/valid result transport.
- Added widened affine integer requantization with per-column parameters.
- Retained original module interfaces and the canonical 4×4 golden result.
- Added per-module benches, a 53-run regression, independent Python-to-RTL vectors, Python cycle/tiling models, strict lint and generic synthesis scripts.
- Replaced raster-only diagrams with editable architecture, PE, schedule and actual-waveform SVG/PNG figures.
- Rewrote README, interface/architecture/verification documentation, migration notes, and CI.

The new features are implementation extensions; this release makes no claim of publication novelty or physical PPA superiority.
