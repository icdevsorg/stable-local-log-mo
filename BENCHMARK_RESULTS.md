# Benchmark results

Benchmarks use Mops Bench with the copying garbage collector and PocketIC.
The checked-in `.bench/log.bench.json` file is the pre-modernization baseline
from moc 1.3.0, `mo:base` 0.16.0, and the previous clear-on-overflow logic.

At 1,000 retained entries, the moc 1.8.2/Core 2.3.1 circular-buffer version
compares as follows:

| Operation | Baseline instructions | Current instructions | Change | Baseline GC | Current GC | Change |
|---|---:|---:|---:|---:|---:|---:|
| Append 1,000 entries | 2,654,986 | 2,693,119 | +1.44% | 104.43 KiB | 104.60 KiB | +0.16% |
| Filtered query | 5,124,856 | 3,868,513 | -24.51% | 168.84 KiB | 109.99 KiB | -34.85% |
| Overflow one entry | 2,658,515 | 2,695,811 | +1.40% | 104.59 KiB | 104.70 KiB | +0.10% |

The old overflow benchmark cleared the whole log. The new result retains the
configured number of newest entries, evicts exactly one oldest entry, and
invokes `onEvict` with that entry. The small rollover cost is therefore paired
with corrected semantics and O(1) replacement.
