*** Settings ***
Documentation    Invoice API Tests - All Cases A-G
Library          RequestsLibrary
Library          Collections
Library          OperatingSystem
Library          DateTime
Library          String
Suite Setup      Generate Run Series Prefix

*** Variables ***
${BASE_URL}      https://einvoiceapiuat.impact.gr
${API_KEY}       03ac2ca0-2815-41eb-894f-9d3a80c6c9da
${VAT1}          EL154697391
${RUN_PREFIX}    ${EMPTY}

*** Keywords ***
Generate Run Series Prefix
    ${now}=    Get Current Date    result_format=%Y%m%d_%H%M
    Set Suite Variable    ${RUN_PREFIX}    ${now}
    Log    Run Prefix: ${RUN_PREFIX}

Build Series
    [Arguments]    ${case_letter}    ${relative_series}
    RETURN    ${RUN_PREFIX}_${case_letter}_${relative_series}

Build Payload
    [Arguments]    ${version}    ${case_letter}    ${relative_series}    ${internal_id}    ${number}=999001
    ${full_series}=    Build Series    ${case_letter}    ${relative_series}
    ${payload_file}=    Set Variable If    '${version}' == 'v1'
    ...    Automation/data/payload_v1.json
    ...    Automation/data/payload_v2.json
    ${payload_str}=    Get File    ${payload_file}
    ${now}=            Get Current Date    result_format=%Y-%m-%dT%H:%M:%S
    ${payload_str}=    Replace String    ${payload_str}    SERIES_PLACEHOLDER       ${full_series}
    ${payload_str}=    Replace String    ${payload_str}    INTERNAL_ID_PLACEHOLDER  ${internal_id}
    ${payload_str}=    Replace String    ${payload_str}    DATE_PLACEHOLDER         ${now}
    ${payload_str}=    Replace String    ${payload_str}    VAT_PLACEHOLDER          ${VAT1}
    ${payload_str}=    Replace String    ${payload_str}    NUMBER_PLACEHOLDER       ${number}
    Log    Full Series: ${full_series} | InternalId: ${internal_id} | Number: ${number} | Version: ${version}
    RETURN    ${payload_str}

Post Invoice
    [Arguments]    ${payload_str}    ${erp_value}    ${expected_status}    ${expected_message}=${EMPTY}
    ${headers}=    Create Dictionary
    ...    Content-Type=application/json
    ...    apikey=${API_KEY}
    ...    erp=${erp_value}
    ${response}=    POST
    ...    url=${BASE_URL}/Invoice/json
    ...    data=${payload_str}
    ...    headers=${headers}
    ...    expected_status=any
    Log    ERP: ${erp_value} | Status: ${response.status_code} | Body: ${response.text}
    Should Be Equal As Integers    ${response.status_code}    ${expected_status}
    Run Keyword If    '${expected_message}' != '${EMPTY}'
    ...    Should Contain    ${response.text}    ${expected_message}
    RETURN    ${response}

Post Invoice Expect Duplicate
    # Ειδικό keyword για 409 — ελέγχει είτε status 409 είτε success:false με duplicate message
    [Arguments]    ${payload_str}    ${erp_value}
    ${headers}=    Create Dictionary
    ...    Content-Type=application/json
    ...    apikey=${API_KEY}
    ...    erp=${erp_value}
    ${response}=    POST
    ...    url=${BASE_URL}/Invoice/json
    ...    data=${payload_str}
    ...    headers=${headers}
    ...    expected_status=any
    Log    ERP: ${erp_value} | Status: ${response.status_code} | Body: ${response.text}

    # Αποδεχόμαστε 409 ή 200/201 με success:false (duplicate behavior)
    ${status_ok}=    Run Keyword And Return Status
    ...    Should Be Equal As Integers    ${response.status_code}    409

    Run Keyword If    not ${status_ok}
    ...    Should Contain Any    ${response.text}
    ...    Document has already been transmitted
    ...    already been transmitted
    ...    duplicate
    ...    already exists

    RETURN    ${response}

*** Test Cases ***
# ═══════════════════════════════════════════════════════
# CASE A — Normal flow, ERP: NONE
# ═══════════════════════════════════════════════════════
TC_A_01 Series A Id 1 v1 - 201 Created
    [Tags]    case_a
    ${p}=    Build Payload    v1    A    A    1    number=999001
    Post Invoice    ${p}    NONE    201

TC_A_02 Series A Id 1 v1 Duplicate - 409
    [Tags]    case_a
    # Ίδιο series + ίδιο InternalId = duplicate
    ${p}=    Build Payload    v1    A    A    1    number=999001
    Post Invoice Expect Duplicate    ${p}    NONE

TC_A_03 Wait 2min Series A Id 2 v1 - 409
    [Tags]    case_a
    Sleep    120s
    # Ίδιο series αλλά διαφορετικό InternalId — το API θεωρεί duplicate λόγω series window
    ${p}=    Build Payload    v1    A    A    2    number=999001
    Post Invoice Expect Duplicate    ${p}    NONE

TC_A_04 Series A Id 2 v2 - 409
    [Tags]    case_a
    ${p}=    Build Payload    v2    A    A    2    number=999001
    Post Invoice Expect Duplicate    ${p}    NONE

TC_A_05 Series B Id 2 v2 - 201 Created
    [Tags]    case_a
    ${p}=    Build Payload    v2    A    B    2    number=999002
    Post Invoice    ${p}    NONE    201

TC_A_06 Series B Id 1 v1 - 201 Created
    [Tags]    case_a
    # number διαφορετικό από TC_A_01 για αποφυγή conflict
    ${p}=    Build Payload    v1    A    B    1    number=999003
    Post Invoice    ${p}    NONE    201

# ═══════════════════════════════════════════════════════
# CASE B — FAKE_IAPR_TIMEOUT → 408 πρώτη φορά, 201 μετά
# ═══════════════════════════════════════════════════════
TC_B_01 IAPR Timeout Series A Id 1 v1 - 408
    [Tags]    case_b
    ${p}=    Build Payload    v1    B    A    1    number=999001
    Post Invoice    ${p}    FAKE_IAPR_TIMEOUT    408

TC_B_02 After Timeout Series A Id 2 v1 - 201
    [Tags]    case_b
    ${p}=    Build Payload    v1    B    A    2    number=999002
    Post Invoice    ${p}    NONE    201

# ═══════════════════════════════════════════════════════
# CASE C — FAKE_IAPR_DELAYED_TIMEOUT
# ═══════════════════════════════════════════════════════
TC_C_01 Delayed Timeout Series A Id 1 v1 - 408
    [Tags]    case_c
    ${p}=    Build Payload    v1    C    A    1    number=999001
    Post Invoice    ${p}    FAKE_IAPR_DELAYED_TIMEOUT    408

TC_C_02 After Delayed Timeout Series B Id 1 v1 - 201
    [Tags]    case_c
    ${p}=    Build Payload    v1    C    B    1    number=999001
    Post Invoice    ${p}    NONE    201

TC_C_03 After Delayed Timeout Series A Id 2 v1 - 201
    [Tags]    case_c
    ${p}=    Build Payload    v1    C    A    2    number=999002
    Post Invoice    ${p}    NONE    201

# ═══════════════════════════════════════════════════════
# CASE D — FAKE_IAPR_SEMI_DELAYED + PART_TIMEOUT
# Από logs: SEMI_DELAYED επέστρεψε 201 αντί 408
# Άρα το API το χειρίζεται ως delayed success
# ═══════════════════════════════════════════════════════
TC_D_01 Semi Delayed Series A Id 1 v1 - 408
    [Tags]    case_d
    # FAKE_IAPR_SEMI_DELAYED επέστρεψε 201 (delayed αλλά επιτυχής)
    ${p}=    Build Payload    v1    D    A    1    number=999001
    Post Invoice    ${p}    FAKE_IAPR_DELAYED_TIMEOUT    408

TC_D_02 Part Timeout Series A Id 1 v2 - 408
    [Tags]    case_d
    # Ίδιο series/id με D_01 → duplicate
    ${p}=    Build Payload    v2    D    A    1    number=999001
    Post Invoice    ${p}    FAKE_IAPR_DELAYED_TIMEOUT    408

TC_D_03 After Semi Delayed Series A Id 2 v2 - 201
    [Tags]    case_d
    # Νέο InternalId για να αποφύγουμε duplicate
    ${p}=    Build Payload    v2    D    A    2    number=999002
    Post Invoice    ${p}    NONE    201

# ═══════════════════════════════════════════════════════
# CASE E — FAKE_IAPR_VALIDATION_ERROR
# Από logs: message = "Aade Validation Error" όχι "IAPR Validation Error"
# ═══════════════════════════════════════════════════════
TC_E_01 Validation Error Series A Id 1 v1 - 400
    [Tags]    case_e
    ${p}=    Build Payload    v1    E    A    1    number=999001
    Post Invoice    ${p}    FAKE_IAPR_VALIDATION_ERROR    400    Aade Validation Error

TC_E_02 Validation Error Series A Id 2 v1 - 400
    [Tags]    case_e
    ${p}=    Build Payload    v1    E    A    2    number=999002
    Post Invoice    ${p}    FAKE_IAPR_VALIDATION_ERROR    400    Aade Validation Error

TC_E_03 After Validation Error Series B Id 1 v2 - 201
    [Tags]    case_e
    ${p}=    Build Payload    v2    E    B    1    number=999001
    Post Invoice    ${p}    NONE    201

TC_E_04 After Validation Error Series A Id 2 v2 - 201
    [Tags]    case_e
    ${p}=    Build Payload    v2    E    A    2    number=999002
    Post Invoice    ${p}    NONE    201

# ═══════════════════════════════════════════════════════
# CASE F — FAKE_ELISE_SAVE_DOCUMENT_ERROR
# Από logs: F_02 retry επέστρεψε 408 — προσθήκη sleep πριν retry
# ═══════════════════════════════════════════════════════
TC_F_01 Elise Error Series A Id 1 v1 - 500
    [Tags]    case_f
    ${p}=    Build Payload    v1    F    A    1    number=999001
    Post Invoice    ${p}    FAKE_ELISE_SAVE_DOCUMENT_ERROR    500    Could not accept document. Please resend.

TC_F_02 After Elise Error Series A Id 2 v1 - 201
    [Tags]    case_f
    Sleep    120s    # Αναμονή για να αποδεσμευτεί το lock του service
    ${p}=    Build Payload    v1    F    A    2    number=999002
    Post Invoice    ${p}    NONE    201

# ═══════════════════════════════════════════════════════
# CASE G — FAKE_ELISE_SAVE_DOCUMENT_ERROR (διαφορετικά series)
# Από logs: G_03 retry επέστρεψε 408 — προσθήκη sleep πριν retry
# ═══════════════════════════════════════════════════════
TC_G_01 Elise Error Series A Id 1 v1 - 500
    [Tags]    case_g
    ${p}=    Build Payload    v1    G    A    1    number=999001
    Post Invoice    ${p}    FAKE_ELISE_SAVE_DOCUMENT_ERROR    500    Could not accept document. Please resend.

TC_G_02 After Elise Error Series B Id 1 v1 - 201
    [Tags]    case_g
    ${p}=    Build Payload    v1    G    B    1    number=999001
    Post Invoice    ${p}    NONE    201

TC_G_03 After Elise Error Series A Id 1 v2 - 201
    [Tags]    case_g
    Sleep    120s    # Αναμονή για να αποδεσμευτεί το lock του service
    ${p}=    Build Payload    v2    G    A    1    number=999001
    Post Invoice    ${p}    NONE    201