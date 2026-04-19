*** Settings ***
Resource    resources/ocpp_keywords.resource
Test Setup    Reset OCPP Simulator


*** Test Cases ***
Happy Path Full Session Lifecycle
    ${start}=    Send Start    tx-happy-001    1    1000    2026-04-19T10:00:00Z
    Should Be Equal    ${start}    ACCEPTED
    Send Meter    tx-happy-001    1050    2026-04-19T10:01:00Z
    Send Meter    tx-happy-001    1120    2026-04-19T10:02:00Z
    Send Meter    tx-happy-001    1190    2026-04-19T10:03:00Z
    Send Meter    tx-happy-001    1250    2026-04-19T10:04:00Z
    Send Meter    tx-happy-001    1310    2026-04-19T10:05:00Z
    ${stop}=    Send Stop    tx-happy-001    1360    2026-04-19T10:06:00Z
    Should Be Equal    ${stop}    ACCEPTED
    Assert Session State    tx-happy-001    COMPLETED
    Assert Session Energy Wh    tx-happy-001    360

Duplicate StartTransaction Is Idempotent
    ${start_one}=    Send Start    tx-dup-001    2    5000    2026-04-19T11:00:00Z
    Should Be Equal    ${start_one}    ACCEPTED
    ${start_two}=    Send Start    tx-dup-001    2    5000    2026-04-19T11:00:10Z
    Should Be Equal    ${start_two}    NO_OP_DUPLICATE
    Assert Duplicate Start Count    tx-dup-001    1
    Assert Open Session Count For Connector    2    1
    ${stop}=    Send Stop    tx-dup-001    5200    2026-04-19T11:10:00Z
    Should Be Equal    ${stop}    ACCEPTED
    Assert Session State    tx-dup-001    COMPLETED

Decreasing Meter Value Faults Session
    ${start}=    Send Start    tx-fault-001    3    2000    2026-04-19T12:00:00Z
    Should Be Equal    ${start}    ACCEPTED
    Send Meter    tx-fault-001    2100    2026-04-19T12:01:00Z
    Send Meter    tx-fault-001    2090    2026-04-19T12:02:00Z
    ${stop}=    Send Stop    tx-fault-001    2200    2026-04-19T12:10:00Z
    Should Be Equal    ${stop}    ACCEPTED
    Assert Session State    tx-fault-001    FAULTED
    Assert Session Anomaly    tx-fault-001    DECREASING_METER_VALUE

Offline Replay Stop Before MeterValues
    ${start}=    Send Start    tx-offline-001    4    3000    2026-04-19T13:00:00Z
    Should Be Equal    ${start}    ACCEPTED
    ${stop}=    Send Stop    tx-offline-001    3500    2026-04-19T13:06:00Z
    Should Be Equal    ${stop}    ACCEPTED
    Send Meter    tx-offline-001    3120    2026-04-19T13:02:00Z
    Send Meter    tx-offline-001    3240    2026-04-19T13:03:00Z
    Send Meter    tx-offline-001    3380    2026-04-19T13:04:00Z
    Assert Session State    tx-offline-001    COMPLETED
    Assert Session Energy Wh    tx-offline-001    500
