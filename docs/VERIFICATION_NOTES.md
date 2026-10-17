# Verification Notes

## Reference model

The randomized testbench keeps a small behavioral queue using:

- `model[]` for expected data
- `model_wr_ptr` for the next expected write position
- `model_rd_ptr` for the next expected read position
- `model_count` for expected occupancy

Accepted read/write operations are determined from the model's **pre-edge** occupancy. This is important for simultaneous operations: a read cannot become valid merely because a write was requested in the same cycle when the FIFO started empty.

## Random traffic phases and coverage

The randomized loop switches between balanced (50/50), write-heavy (80/20) and read-heavy (20/80) request probabilities every 250 cycles. With balanced traffic only, a depth-16 FIFO never reached full in 1,000 cycles, so the full-related corner cases were never exercised.

Coverage counters (write while full, read while empty, read+write in the middle / while full / while empty) are sampled from pre-edge state. If any counter is zero at the end, the run fails.

## Pass/fail signalling

Any failed check makes the testbench call `$fatal(1, ...)`, which gives a non-zero simulator exit code. `make`, CI and `scripts/run_tests.bat` rely on that exit code, so a failure cannot be missed by only reading the log.

## Expected result

A successful run ends with a line similar to:

```text
TEST PASSED: <number> checks
```

The exact number of checks can vary if the randomized testbench is changed.
