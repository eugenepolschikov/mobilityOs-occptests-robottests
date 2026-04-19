*** Settings ***
Library    ../libraries/OcppSimulatorLibrary.py


*** Keywords ***
Reset OCPP Simulator
    Reset Simulator State

Send Start
    [Arguments]    ${transaction_id}    ${connector_id}    ${meter_start}    ${timestamp}
    ${result}=    Send Start Transaction    ${transaction_id}    ${connector_id}    ${meter_start}    ${timestamp}
    RETURN    ${result}

Send Meter
    [Arguments]    ${transaction_id}    ${meter_value}    ${timestamp}
    ${result}=    Send Meter Value    ${transaction_id}    ${meter_value}    ${timestamp}
    RETURN    ${result}

Send Stop
    [Arguments]    ${transaction_id}    ${meter_stop}    ${timestamp}
    ${result}=    Send Stop Transaction    ${transaction_id}    ${meter_stop}    ${timestamp}
    RETURN    ${result}

Assert Session State
    [Arguments]    ${transaction_id}    ${expected_state}
    ${actual}=    Get Session State    ${transaction_id}
    Should Be Equal    ${actual}    ${expected_state}

Assert Session Energy Wh
    [Arguments]    ${transaction_id}    ${expected_wh}
    ${actual}=    Get Session Energy Wh    ${transaction_id}
    Should Be Equal As Integers    ${actual}    ${expected_wh}

Assert Duplicate Start Count
    [Arguments]    ${transaction_id}    ${expected_count}
    ${actual}=    Get Duplicate Start Count    ${transaction_id}
    Should Be Equal As Integers    ${actual}    ${expected_count}

Assert Open Session Count For Connector
    [Arguments]    ${connector_id}    ${expected_count}
    ${actual}=    Get Open Session Count For Connector    ${connector_id}
    Should Be Equal As Integers    ${actual}    ${expected_count}

Assert Session Anomaly
    [Arguments]    ${transaction_id}    ${expected_anomaly}
    ${actual}=    Get Session Anomaly    ${transaction_id}
    Should Be Equal    ${actual}    ${expected_anomaly}
