# Task 2 - Nebula/Cortex Edge Device Validation Strategy

## 3.1 Offline Resilience Testing

### How to simulate cloud disconnection
- Use network fault injection between edge controller and cloud endpoint:
  - `toxiproxy` to cut TCP connections, inject latency, and packet loss.
  - Host firewall rules (`netsh advfirewall`) to block cloud IP/port.
  - Docker network disconnect if controller runs in containerized test env.
- Drive tests from CI with deterministic profiles (e.g., disconnect for 15 minutes, reconnect with jitter).

### Offline behavior assertions (minimum 5)
1. Dispatch loop continues locally (charge/discharge setpoints still sent on schedule).
2. Last valid control policy is retained (no reset to unsafe defaults).
3. Telemetry is buffered durably (survives process restart during outage).
4. Local safety constraints remain enforced (SoC, power, temperature guardrails).
5. No command duplication after reconnect (idempotent command application).
6. Health state reflects cloud unavailable but device remains operational locally.
7. SIGTERM-safe shutdown during outage leaves queue and state consistent.

### Replay verification after reconnect (complete and in-order)
- Add monotonically increasing sequence IDs to buffered telemetry records.
- On reconnect:
  - Capture replayed stream at ingress/API mock and assert contiguous sequence (`n..m` no gaps/dupes).
  - Assert ordering by `(site_id, sequence_id)` and, secondarily, timestamp.
  - Compare source queue count with cloud-ingested count.
  - Validate end-of-replay checkpoint equals last local buffered offset.
- Include negative checks: intentionally drop packet at reconnect and ensure retry fills gap.

### Risk of not testing offline resilience (realistic scenario)
A site loses WAN connectivity during a high-price discharge window. Without validated offline behavior, the edge controller stops dispatching and leaves battery in stale charge state. On reconnect, telemetry replay is partial and out-of-order, so cloud believes discharge happened and submits incorrect settlement data. Result: lost market revenue, balancing penalties, and potential battery stress from delayed correction commands.

## 3.2 Modbus TCP Test Cases (No Hardware)

### Recommended simulation approach
- Use a software Modbus slave/server:
  - `pymodbus` async server (fully scriptable in tests), or
  - `mbserver`/`modbus-tk` for simple register maps.
- Wrap simulator with a test harness that can:
  - inspect register writes,
  - force disconnects/timeouts,
  - delay specific write acknowledgments.

### TC-MODBUS-001 Charge command updates charge register
- **Simulation**: Start Modbus simulator with known holding registers:
  - `charge_cmd_reg`, `discharge_cmd_reg` initialized to `0`.
- **Test**:
  1. Send edge command `CHARGE=1`.
  2. Read simulator registers.
- **Expected**:
  - `charge_cmd_reg=1`.
  - `discharge_cmd_reg` unchanged/`0`.

### TC-MODBUS-002 Discharge clears charge then sets discharge
- **Simulation**: Register write hook records write order with timestamps.
- **Test**:
  1. Pre-set `charge_cmd_reg=1`.
  2. Send edge command `DISCHARGE=1`.
  3. Verify write sequence.
- **Expected**:
  - First write sets `charge_cmd_reg=0`.
  - Second write sets `discharge_cmd_reg=1`.
  - No intermediate state with both set to `1`.

### TC-MODBUS-003 Emergency stop zeroes both registers immediately
- **Simulation**: Run controller against simulator; inject active charge/discharge.
- **Test**:
  1. Trigger emergency stop input.
  2. Read both registers within strict timeout (e.g., <200 ms).
- **Expected**:
  - `charge_cmd_reg=0` and `discharge_cmd_reg=0` in same control cycle.
  - Edge transitions to safe state.

### TC-MODBUS-004 Connection lost mid-command with exponential backoff
- **Simulation**: Force socket drop after first write packet; restore after N seconds.
- **Test**:
  1. Send command requiring write.
  2. Observe retry intervals and reconnect behavior.
- **Expected**:
  - Retries follow exponential backoff (e.g., 1s, 2s, 4s, capped).
  - Command eventually succeeds after connection restore.
  - Exactly one effective register state change at end.

### TC-MODBUS-005 Connection never recovers -> safe idle
- **Simulation**: Keep Modbus endpoint permanently unavailable.
- **Test**:
  1. Attempt charge/discharge command.
  2. Observe controller for timeout window.
- **Expected**:
  - Controller enters safe idle/faulted communication mode.
  - No stuck pending command that later executes unexpectedly.
  - Alarm raised with clear operator diagnostics.
