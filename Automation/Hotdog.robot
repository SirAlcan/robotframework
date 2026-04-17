*** Settings ***
Documentation   Hotdog
Library         SeleniumLibrary

*** Variables ***
${urlHotdog}      https://hotdoc.impact.gr/
${Browser1}       Chrome
${userEmail1}     gregkazakou@gmail.com
${pwd1}           Papaki2!
${companyTIN1}    135952929

*** Keywords ***
*** Keywords ***
Do Login
    [Documentation]    login - for all TC
    [Arguments]    ${email}=${userEmail1}    ${password}=${pwd1}
    Open Browser    ${urlHotdog}    Chrome    options=add_argument("--headless");add_argument("--no-sandbox");add_argument("--disable-dev-shm-usage");add_argument("--disable-gpu");add_argument("--window-size=1920,1080")
    Sleep                     2s
    Click Element             xpath=//a[@href='/auth/login']
    Sleep                     4s
    Element Should Be Disabled    id=loginButton
    Input Text                id=emailInput             ${email}
    Input Password            name=LoginInput.Password  ${password}
    Click Element             id=loginButton

Select Company
    [Arguments]    ${companyTIN1}
    Wait Until Element Is Visible    xpath=//input[@placeholder='Αναζήτηση εταιρίας μέσω ΑΦΜ']    timeout=10s
    Clear Element Text               xpath=//input[@placeholder='Αναζήτηση εταιρίας μέσω ΑΦΜ']
    Input Text                       xpath=//input[@placeholder='Αναζήτηση εταιρίας μέσω ΑΦΜ']    ${companyTIN1}
    Wait Until Element Is Enabled    xpath=//button[@data-variant='outline' and .//span[text()='Αναζήτηση']]    timeout=5s
    Execute Javascript    document.evaluate("//button[@data-variant='outline' and .//span[text()='Αναζήτηση']]", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.click()
    Sleep    3s
    Wait Until Element Is Visible    xpath=//button[@data-slot="button" and contains(., "Επιλογή")]    timeout=5s
    Execute Javascript    document.evaluate("//button[@data-slot='button' and contains(., 'Επιλογή')]", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.click()
    Sleep    2s
    Wait Until Element Is Visible    xpath=//li[@data-sonner-toast]//div[contains(text(), "Η εταιρεία") and contains(text(), "επιλέχθηκε")]    timeout=10s

*** Test Cases ***
TC1 Login Success
    Do Login
    Sleep    4s
    Close Browser

TC2 Login Wrong Email
    Do Login    email=invalid-email@email.com
    Wait Until Element Is Visible    xpath=//div[@class='validation-message' and (normalize-space()='Check your email address' or normalize-space()='Έλεγξε τη διεύθυνση email σου')]
    Sleep    3s
    Close Browser

TC3 Login Wrong Password
    Do Login    password=wrongpassword
    Wait Until Element Is Visible    xpath=//div[@class='validation-message' and (normalize-space()='Ο κωδικός πρόσβασης δεν είναι σωστός' or normalize-space()='The password is incorrect')]
    Sleep    3s
    Close Browser

TC4 Select Company Success
    [Setup]    Do Login
    Select Company    ${companyTIN1}
    [Teardown]    Close Browser