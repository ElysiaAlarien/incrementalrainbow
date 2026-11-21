# Large numbers as a float mantissa and an int exponent

The game has no end, so money and prices must grow far past 64-bit limits. `BigNumber` stores a value as a float mantissa in [1, 10) and an int exponent. It holds values up to about 10^(9.2e18) and keeps 15 significant digits: each new value rounds its mantissa to 15 digits, so that float error does not build up and whole-number money stays exact (100 - 30 is exactly 70, and a cost equal to the money can be paid). Add, multiply, and compare take constant time. We rejected an arbitrary-precision integer because its cost grows with the number of digits, and an incremental game does not need exact digits in very large values. We rejected a plain float because it stops at about 1.8e308.

Counts that stay small, such as widgets in a bay, stay plain ints. The screen shows every number through `BigNumber.format()`, which uses short suffixes (K, M, B, ...) up to 10^35, then scientific notation.
