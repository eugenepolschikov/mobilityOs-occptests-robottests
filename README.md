# Laryan Mobility OS Validation Exercise

This repository contains:
- Task 1: complete OCPP session lifecycle test case design (`docs/task1_ocpp_test_suite.md`)
- Task 2: Nebula/Cortex edge validation strategy (`docs/task2_nebula_cortex_validation.md`)
- Task 3: runnable Robot Framework automation for OCPP scenarios (`tests/`)

## Prerequisites
- Python 3.10+ (validated with Python 3.13)
- `pip`

## Setup
```bash
pip install -r requirements.txt
```

## Run automated tests
```bash
robot tests/
```

## Automated scenarios implemented
- Happy path full session lifecycle
- Duplicate StartTransaction idempotency
- Decreasing meter value anomaly detection
- Offline replay where StopTransaction arrives before MeterValues

## Project layout
- `tests/ocpp_session_lifecycle.robot` - Robot test suite
- `tests/resources/ocpp_keywords.resource` - reusable Robot keywords
- `tests/libraries/OcppSimulatorLibrary.py` - in-memory simulator keyword library
- `docs/task1_ocpp_test_suite.md` - structured manual OCPP test design
- `docs/task2_nebula_cortex_validation.md` - edge/offline + Modbus validation strategy
