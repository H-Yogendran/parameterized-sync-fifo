# Verification Notes

## Reference model

The randomized testbench keeps a small behavioral queue using:

- `model[]` for expected data
- `model_wr_ptr` for the next expected write position
- `model_rd_ptr` for the next expected read position
- `model_count` for expected occupancy

Accepted read/write operations are determined from the model's **pre-edge** occupancy. This is important for simultaneous operations: a read cannot become valid merely because a write was requested in the same cycle when the FIFO started empty.

## Expected result

A successful run ends with a line similar to:

```text
TEST PASSED: <number> checks
```

The exact number of checks can vary if the randomized testbench is changed.
