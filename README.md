# Parameterized Synchronous FIFO

A synthesizable, parameterized synchronous FIFO implemented in Verilog with a self-checking verification environment.

## Features

- Configurable `WIDTH` and `DEPTH`
- Synchronous reset
- Single-clock operation
- `wr_en` / `rd_en` controls
- `full` / `empty` status flags
- Occupancy `count`
- FIFO ordering (first in, first out)
- Pointer wrap-around
- Overflow protection
- Underflow protection
- Simultaneous read/write support
- Randomized verification against a behavioral reference model
- Parameterization smoke test

## Architecture

The FIFO stores data in a memory array and tracks two pointers:

- `wr_ptr`: next location to receive a write
- `rd_ptr`: next location to be returned by a read
- `count`: number of valid entries currently stored

```text
                  +----------------------+
      din ------>|                      |
      wr_en ---->|     FIFO Memory      |----> dout
                 |                      |
                 +----------+-----------+
                            ^
                       wr_ptr / rd_ptr
                            |
                 +----------+-----------+
                 |                      |
                 | Occupancy Counter    |
                 |       count          |
                 +----+------------+----+
                      |            |
                    empty        full
```

The design uses `count` to distinguish empty and full states. Both states can otherwise have the pointers at the same relative position after wrap-around, so the occupancy count removes that ambiguity.

## Operation

A write is accepted when:

```text
wr_en = 1 AND FIFO is not full
```

A read is accepted when:

```text
rd_en = 1 AND FIFO is not empty
```

If both operations are accepted during the same clock edge, one item is removed and one item is inserted, so occupancy remains unchanged.

At full capacity, a simultaneous read/write accepts the read but rejects the write because the design evaluates `full` from the pre-edge state.

## Verification

The main testbench checks:

1. Reset
2. Fill to full
3. Overflow rejection
4. FIFO ordering while draining
5. Empty state
6. Underflow rejection
7. Simultaneous read/write
8. Pointer wrap-around
9. 1,000 randomized read/write cycles
10. Data output against a behavioral reference model
11. `count`, `full`, and `empty` against the reference model

The parameterization smoke test instantiates the same RTL with `WIDTH=16` and `DEPTH=8`.

## Run

From the project root on Windows:

```text
scripts\run_tests.bat
```

Or manually:

```text
iverilog -o fifo_sim rtl/sync_fifo.v tb/sync_fifo_tb.v
vvp fifo_sim
```

The testbench also produces:

```text
sync_fifo_tb.vcd
```

which can be opened in a waveform viewer such as GTKWave.

## Design Notes

`COUNT_WIDTH` is `$clog2(DEPTH+1)` because `count` must represent every occupancy from `0` through `DEPTH`.

The pointer width is based on `DEPTH` rather than `DEPTH+1` because pointers identify storage locations, not occupancy levels. Explicit wrap-around logic returns each pointer to zero after the final memory location.

Memory contents do not need to be cleared when reading. Once `rd_ptr` advances, the old entry is no longer logically part of the FIFO.

## Scope

This is a synchronous FIFO. Clock-domain crossing and asynchronous FIFO techniques are intentionally outside the scope of this project.
