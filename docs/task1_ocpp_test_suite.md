# Task 1 - OCPP Session Lifecycle Test Suite Design

## Scope
EVRA OCPP 1.6J session lifecycle validation for connector/session behavior, ordering, anomaly handling, and offline replay handling.

## TC-OCPP-001 - Happy Path Session Lifecycle
- **Preconditions**
  - Charger is connected and online.
  - No active session on `connectorId=1`.
  - Transaction ID `tx-001` does not exist.
- **Steps**
  1. Send `StartTransaction(tx-001, connectorId=1, meterStart=1000, timestamp=t0)`.
  2. Send 5 `MeterValues` at `t1..t5`: `1050, 1120, 1190, 1250, 1310`.
  3. Send `StopTransaction(tx-001, meterStop=1360, timestamp=t6)`.
- **Expected result**
  - Start/stop accepted.
  - Session transitions `OPEN -> COMPLETED`.
  - Energy computed as `1360 - 1000 = 360 Wh`.
  - No anomaly flags.
- **Pass/Fail criteria**
  - **Pass** if one completed session exists with `energyWh=360` and clean status.
  - **Fail** if energy mismatch, wrong state, or any rejected message.

## TC-OCPP-002 - Duplicate StartTransaction Idempotency
- **Preconditions**
  - Charger online; no active session on `connectorId=2`.
  - `tx-dup-001` does not exist.
- **Steps**
  1. Send `StartTransaction(tx-dup-001, connectorId=2, meterStart=5000, timestamp=t0)`.
  2. Re-send identical `StartTransaction(tx-dup-001, connectorId=2, meterStart=5000, timestamp=t0+10s)`.
  3. Send `StopTransaction(tx-dup-001, meterStop=5200, timestamp=t1)`.
- **Expected result**
  - First start accepted, second start treated as no-op duplicate.
  - Exactly one session record exists.
  - Session completes normally.
- **Pass/Fail criteria**
  - **Pass** if duplicate counter increments but open session count remains `1`.
  - **Fail** if a second session is created or connector state corrupts.

## TC-OCPP-003 - Offline Replay (Stop Before MeterValues)
- **Preconditions**
  - Charger intermittently connected; buffering enabled.
  - `tx-offline-001` does not exist.
- **Steps**
  1. Send `StartTransaction(tx-offline-001, connectorId=3, meterStart=3000, timestamp=t0)`.
  2. Send `StopTransaction(tx-offline-001, meterStop=3500, timestamp=t6)`.
  3. Replay buffered `MeterValues` late with timestamps `t2,t3,t4`: `3120,3240,3380`.
  4. Trigger session recompute/finalization job if async architecture requires it.
- **Expected result**
  - Stop is accepted and session remains internally reconcilable.
  - Late MeterValues are attached to same transaction.
  - Energy includes all points and equals `500 Wh`.
- **Pass/Fail criteria**
  - **Pass** if final state is `COMPLETED`, no dropped readings, energy correct.
  - **Fail** if late messages are ignored, wrong transaction mapping, or wrong energy.

## TC-OCPP-004 - Out-of-Order MeterValues
- **Preconditions**
  - Active transaction `tx-oo-001` started at `t0` with `meterStart=10000`.
- **Steps**
  1. Send `MeterValues` in reverse order: `(t3,10300)`, `(t2,10200)`, `(t1,10100)`.
  2. Send `StopTransaction(tx-oo-001, meterStop=10400, timestamp=t4)`.
- **Expected result**
  - Backend sorts by timestamp before validation and energy calculation.
  - No false anomaly.
  - Energy `400 Wh`.
- **Pass/Fail criteria**
  - **Pass** if sorted reconstruction is visible in persisted timeline and output.
  - **Fail** if ingestion order is used directly and causes wrong energy/anomaly.

## TC-OCPP-005 - Decreasing Meter Value Anomaly
- **Preconditions**
  - `tx-fault-001` started on free connector with `meterStart=2000`.
- **Steps**
  1. Send `MeterValues(t1,2100)`.
  2. Send `MeterValues(t2,2090)` (decreasing).
  3. Send `StopTransaction(tx-fault-001, meterStop=2200, timestamp=t3)`.
- **Expected result**
  - Session flagged `FAULTED`.
  - Anomaly code recorded, e.g. `DECREASING_METER_VALUE`.
  - Session not silently completed.
- **Pass/Fail criteria**
  - **Pass** if fault state + anomaly audit record exist.
  - **Fail** if system completes session without anomaly trace.

## TC-OCPP-006 - Heartbeat Timeout
- **Preconditions**
  - Charger is currently online and heartbeat interval configured.
  - Last heartbeat timestamp known.
- **Steps**
  1. Stop heartbeats for more than 5 minutes.
  2. Run heartbeat monitor tick/scheduler.
- **Expected result**
  - Charger status transitions to offline/unreachable.
  - Alert/event emitted to monitoring.
- **Pass/Fail criteria**
  - **Pass** if status changes within timeout window and telemetry reflects offline state.
  - **Fail** if charger remains online beyond SLA.

## TC-OCPP-007 - StopTransaction Without StartTransaction
- **Preconditions**
  - No session for transaction ID `tx-missing-start`.
- **Steps**
  1. Send `StopTransaction(tx-missing-start, meterStop=1500, timestamp=t0)`.
- **Expected result**
  - Clean rejection (domain error) with no process crash.
  - Error logged with correlation ID.
- **Pass/Fail criteria**
  - **Pass** if service remains healthy and message is rejected deterministically.
  - **Fail** if crash, inconsistent DB writes, or phantom session creation.

## TC-OCPP-008 - Concurrent Sessions on Same Connector
- **Preconditions**
  - `connectorId=4` has no active session.
  - Two clients can issue StartTransaction nearly simultaneously.
- **Steps**
  1. Send `StartTransaction(tx-a, connectorId=4, meterStart=4000, timestamp=t0)`.
  2. Within milliseconds, send `StartTransaction(tx-b, connectorId=4, meterStart=4010, timestamp=t0+delta)`.
  3. Query active sessions for connector.
- **Expected result**
  - Exactly one start accepted.
  - Second rejected as connector busy (or no-op if identical transaction semantics apply).
  - No split-brain in connector session lock.
- **Pass/Fail criteria**
  - **Pass** if single active transaction exists and lock semantics are deterministic.
  - **Fail** if both sessions open or connector state becomes inconsistent.
