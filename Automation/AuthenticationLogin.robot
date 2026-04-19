*** Settings ***

Documentation    Test case  to Authentication/login
Library  RequestsLibrary
Library  collections

*** Variables ***
${uatAPI}         https://einvoiceapiuat.impact.gr
${INVOICE_PATH}     /Invoice/json
${API_KEY}          03ac2ca0-2815-41eb-894f-9d3a80c6c9da
${issuerTIN}             EL154697391
${ERP}              FAKE_IAPR_TIMEOUT    # Override από CLI ή GitHub Actions matrix

*** Test Cases ***
Authentication/login
    Create Session    mysession    ${uatAPI}

    ${body}=    Create Dictionary    key=${apiKey}    vat=${issuerTIN}
    ${header}=    Create Dictionary    Content-Type=application/json

    ${response}=    POST On Session    mysession    /Authentication/login    json=${body}    headers=${header}

    ${json}=    Set Variable    ${response.json()}

    ${access_token}=    Set Variable    ${json['accessToken']}
    ${refresh_token}=    Set Variable    ${json['refreshToken']['token']}

    Set Global Variable    ${access_token}
    Set Global Variable    ${refresh_token}

    Log To Console    Access Token: ${access_token}
    Log To Console    Refresh Token: ${refresh_token}

*** Keywords ***



