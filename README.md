# Laryan Mobility OS Validation Exercise

This repository contains:
- runnable Robot Framework automation for OCPP scenarios (`tests/`)

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
