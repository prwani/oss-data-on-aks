# ClickHouse architecture notes

ClickHouse should be modeled as a stateful analytical database platform with deliberate storage and topology choices.

## Initial design goals

- durable and performant storage layout
- cluster topology that matches analytical workload patterns
- explicit private access and client connectivity guidance
- operational focus on merge, replication, and backup behavior

