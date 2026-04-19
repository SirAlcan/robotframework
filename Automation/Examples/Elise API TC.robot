*** Settings ***
Documentation    Invoice API Tests - Case A
Library          RequestsLibrary
Library          Collections
Library          String
Library          DateTime
Library          OperatingSystem

*** Variables ***
${BASE_URL}         https://einvoiceapiuat.impact.gr
${INVOICE_PATH}     /Invoice/json
${API_KEY}          03ac2ca0-2815-41eb-894f-9d3a80c6c9da
${VAT1}             EL154697391
${ERP}              FAKE_IAPR_TIMEOUT    # Override από CLI ή GitHub Actions matrix

# Summaries v1 (από το αρχικό JSON)
${NET_V1}           ${133.93}
${VAT_V1}           ${20.07}
${GROSS_V1}         ${154}

# Summaries v2 (διαφορετικά ποσά)
${NET_V2}           ${200.00}
${VAT_V2}           ${30.00}
${GROSS_V2}         ${230}

${SEPARATOR}        ============================================================

*** Keywords ***
Create Invoice Session
    [Documentation]    Δημιουργεί session με τα απαραίτητα headers
    ${headers}=    Create Dictionary
    ...    Content-Type=application/json
    ...    apikey=${API_KEY}
    ...    erp=${ERP}
    Create Session    invoice_api    ${BASE_URL}    headers=${headers}    verify=True
    Log    Session δημιουργήθηκε με ERP=${ERP}    console=True

Build Invoice Payload
    [Documentation]    Χτίζει το JSON payload δυναμικά
    [Arguments]    ${series}    ${internal_doc_id}    ${net}    ${vat_amount}    ${gross}

    # --- Issuer ---
    ${phones}=          Create List    2000000000
    ${faxes}=           Create List    2000000000
    ${address}=         Create Dictionary
    ...    CountryCode=GR
    ...    City=issuer's city
    ...    Street=issuer's street
    ...    Number=issuer's number
    ...    Postal=issuer's postal code
    ${issuer}=          Create Dictionary
    ...    RegisteredName=issuer's name
    ...    Vat=${VAT1}
    ...    GeneralCommercialRegistryNumber=00000000000
    ...    TaxOffice=issuer's Tax Office
    ...    contactPerson=issuer's Contact Person
    ...    Phones=${phones}
    ...    Faxes=${faxes}
    ...    Address=${address}
    ...    BranchCode=${0}
    ...    Branch=Main Branch

    # --- AdditionalDetails ---
    ${acct_emails}=     Create List    gkazakou@impact.gr
    ${cells}=           Create List    +30000000000
    ${pdf_emails}=      Create List    gkazakou@impact.gr
    ${doc_tags}=        Create List    transactionType=FNB    ERP=TEST
    ${additional}=      Create Dictionary
    ...    TransmissionMethod=A
    ...    accountingDepartmentEmails=${acct_emails}
    ...    customerCellNumbers=${cells}
    ...    sendAsPdf=${False}
    ...    pdfNotificationEmails=${pdf_emails}
    ...    documentTemplate=${None}
    ...    DocumentTags=${doc_tags}

    # --- DistributionDetails ---
    ${distribution}=    Create Dictionary
    ...    InternalDocumentId=${internal_doc_id}
    ...    salesman=Waiter A1
    ...    content=3

    # --- Details Line 1 ---
    ${desc1}=           Create List    Product's specifications
    ${income1}=         Create Dictionary
    ...    ClassificationTypeCode=${EMPTY}
    ...    ClassificationCategoryCode=category1_95
    ${line1}=           Create Dictionary
    ...    LineNo=${1}
    ...    code=251320104
    ...    Descriptions=${desc1}
    ...    MeasurementUnitCode=${1}
    ...    MeasurementUnit=Pieces
    ...    Quantity=${100}
    ...    UnitPrice=${1.09}
    ...    allowancesTotal=${0.0}
    ...    NetTotal=${109.73}
    ...    VatCategory=13
    ...    VatCategoryCode=${2}
    ...    VATTotal=${14.27}
    ...    Total=${124}
    ...    IsInformative=${False}
    ...    IsHidden=${False}
    ...    RecordTypeCode=${0}
    ...    noVat=${True}
    ...    IncomeClassification=${income1}

    # --- Details Line 2 ---
    ${desc2}=           Create List    Product's specifications
    ${income2}=         Create Dictionary
    ...    ClassificationTypeCode=${EMPTY}
    ...    ClassificationCategoryCode=category1_95
    ${line2}=           Create Dictionary
    ...    LineNo=${2}
    ...    code=256844
    ...    Descriptions=${desc2}
    ...    MeasurementUnitCode=${1}
    ...    MeasurementUnit=Pieces
    ...    Quantity=${2}
    ...    UnitPrice=${12.1}
    ...    allowancesTotal=${0.0}
    ...    NetTotal=${24.2}
    ...    VatCategory=24
    ...    VatCategoryCode=${1}
    ...    VATTotal=${5.8}
    ...    Total=${30}
    ...    IsInformative=${False}
    ...    IsHidden=${False}
    ...    RecordTypeCode=${0}
    ...    noVat=${True}
    ...    IncomeClassification=${income2}

    ${details}=         Create List    ${line1}    ${line2}

    # --- Summaries ---
    ${summaries}=       Create Dictionary
    ...    totalAllowances=${0.0}
    ...    TotalNetAmount=${net}
    ...    TotalVATAmount=${vat_amount}
    ...    TotalGrossValue=${gross}

    # --- VatAnalysis ---
    ${vat_entry1}=      Create Dictionary
    ...    Percentage=${13.0}
    ...    VatAmount=${5.8}
    ...    UnderlyingValue=${109.73}
    ${vat_entry2}=      Create Dictionary
    ...    Percentage=${24.0}
    ...    VatAmount=${14.27}
    ...    UnderlyingValue=${24.2}
    ${vat_analysis}=    Create List    ${vat_entry1}    ${vat_entry2}

    # --- Κύριο Payload ---
    ${payload}=         Create Dictionary
    ...    IsDelayedCode=${0}
    ...    Currency=EUR
    ...    CurrencyCode=EUR
    ...    InvoiceType=FNB Form 8.6
    ...    InvoiceTypeCode=8.6
    ...    SpecialInvoiceCategory=${0}
    ...    DocumentTypeCode=INVOICE
    ...    totalCancelDeliveryOrders=${False}
    ...    Series=${series}
    ...    number=999001
    ...    dateIssued=2026-04-18T02:23:28
    ...    RelativeDocuments=@{EMPTY}
    ...    correlatedInvoices=@{EMPTY}
    ...    multipleConnectedMarks=@{EMPTY}
    ...    OrderCode=2
    ...    tableId=20
    ...    Issuer=${issuer}
    ...    AdditionalDetails=${additional}
    ...    DistributionDetails=${distribution}
    ...    Details=${details}
    ...    Summaries=${summaries}
    ...    VatAnalysis=${vat_analysis}

    RETURN    ${payload}

Post Invoice And Verify
    [Documentation]    Στέλνει POST request και επαληθεύει status και response body
    [Arguments]    ${series}    ${internal_doc_id}    ${net}    ${vat_amount}    ${gross}
    ...            ${expected_status}    ${expected_message}=${EMPTY}

    ${payload}=    Build Invoice Payload
    ...    ${series}    ${internal_doc_id}    ${net}    ${vat_amount}    ${gross}

    Log    POST - Series=${series} | DocId=${internal_doc_id} | Net=${net} | Expected=${expected_status}    console=True

    ${response}=    POST On Session
    ...    invoice_api
    ...    ${INVOICE_PATH}
    ...    json=${payload}
    ...    expected_status=any

    Log    Response Status: ${response.status_code}    console=True
    Log    Response Body  : ${response.text}           console=True

    Should Be Equal As Integers    ${response.status_code}    ${expected_status}
    ...    msg=Expected HTTP ${expected_status} αλλά πήρε ${response.status_code}. Body: ${response.text}

    Run Keyword If    '${expected_message}' != '${EMPTY}'
    ...    Should Contain    ${response.text}    ${expected_message}
    ...    msg=Το response δεν περιέχει το μήνυμα: ${expected_message}

    RETURN    ${response}

Log Sub Case
    [Arguments]    ${number}    ${series}    ${doc_id}    ${summaries_ver}    ${expected}
    Log    ${SEPARATOR}                                                                                        console=True
    Log    Sub-case ${number}: Series=${series} | DocId=${doc_id} | Summaries=${summaries_ver} | Expected=${expected}    console=True
    Log    ${SEPARATOR}                                                                                        console=True

*** Test Cases ***
TC_API_Case_A
    [Documentation]    Case A - 6 sub-cases με ERP=${ERP}
    [Tags]    API    CaseA

    Create Invoice Session

    # Sub-case 1: Series=A, DocId=1, v1 → 201 Created
    Log Sub Case    1    A    1    v1    201 Created
    Post Invoice And Verify
    ...    series=A
    ...    internal_doc_id=1
    ...    net=${NET_V1}
    ...    vat_amount=${VAT_V1}
    ...    gross=${GROSS_V1}
    ...    expected_status=201

    # Sub-case 2: Series=A, DocId=1, v1 → 409 Duplicate
    Log Sub Case    2    A    1    v1    409 Duplicate
    Post Invoice And Verify
    ...    series=A
    ...    internal_doc_id=1
    ...    net=${NET_V1}
    ...    vat_amount=${VAT_V1}
    ...    gross=${GROSS_V1}
    ...    expected_status=409
    ...    expected_message=Document has already been transmitted

    # Αναμονή 2 λεπτών (Condition timing)
    Log    Αναμονή 2 λεπτών πριν το Sub-case 3...    console=True
    Sleep    120s

    # Sub-case 3: Series=A, DocId=2, v1 → 409 Duplicate
    Log Sub Case    3    A    2    v1    409 Duplicate
    Post Invoice And Verify
    ...    series=A
    ...    internal_doc_id=2
    ...    net=${NET_V1}
    ...    vat_amount=${VAT_V1}
    ...    gross=${GROSS_V1}
    ...    expected_status=409
    ...    expected_message=Document has already been transmitted

    # Sub-case 4: Series=A, DocId=2, v2 → 409 Duplicate
    Log Sub Case    4    A    2    v2    409 Duplicate
    Post Invoice And Verify
    ...    series=A
    ...    internal_doc_id=2
    ...    net=${NET_V2}
    ...    vat_amount=${VAT_V2}
    ...    gross=${GROSS_V2}
    ...    expected_status=409
    ...    expected_message=Document has already been transmitted

    # Sub-case 5: Series=B, DocId=2, v2 → 201 Created
    Log Sub Case    5    B    2    v2    201 Created
    Post Invoice And Verify
    ...    series=B
    ...    internal_doc_id=2
    ...    net=${NET_V2}
    ...    vat_amount=${VAT_V2}
    ...    gross=${GROSS_V2}
    ...    expected_status=201

    # Sub-case 6: Series=B, DocId=1, v1 → 201 Created
    Log Sub Case    6    B    1    v1    201 Created
    Post Invoice And Verify
    ...    series=B
    ...    internal_doc_id=1
    ...    net=${NET_V1}
    ...    vat_amount=${VAT_V1}
    ...    gross=${GROSS_V1}
    ...    expected_status=201

    Log    Case A ολοκληρώθηκε επιτυχώς για ERP=${ERP}    console=True
