# Shared Memory Protocol

Dictator-md stores two different layers of user memory:

1. Recent transcript history
   - Contains full dictated text.
   - May be capped per platform for performance and privacy.
   - Must be user-visible and deletable.

2. Analytics ledger
   - Contains lightweight event statistics.
   - Does not need full dictated text.
   - Should be uncapped unless the user explicitly clears it.
   - Powers all-time, yearly, monthly, weekly, and daily stats.

Mobile apps must follow this split from the start. Do not compute all-time stats from a capped transcript list.

