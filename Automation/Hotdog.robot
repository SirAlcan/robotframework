*** Settings ***
Documentation   Hotdog
Library         SeleniumLibrary

*** Variables ***
${urlHotdog}      https://hotdoc.impact.gr/
${Browser1}         Chrome
${HEADLESS}         False    # Τοπικά False, στο GitHub True
${userEmail1}     gregkazakou@gmail.com
${pwd1}           Papaki2!
${companyTIN1}    135952929
${newUserName}      Grigoris Kazakou
${newUserEmail}     gkazakou@impact.gr

*** Keywords ***
Do Login
    [Documentation]    login - for all TC
    [Arguments]    ${email}=${userEmail1}    ${password}=${pwd1}
    Run Keyword If    '${HEADLESS}' == 'True'    Open Headless Browser
    Run Keyword If    '${HEADLESS}' == 'False'   Open Browser    ${urlHotdog}    ${Browser1}
    Sleep    2s
    Click Element     xpath=//a[@href='/auth/login']
    Sleep    4s
    Element Should Be Disabled    id=loginButton
    Input Text        id=emailInput             ${email}
    Click Element     id=loginButton
    Sleep    4s
    Input Password    name=LoginInput.Password  ${password}
    Click Element     id=loginButton

Open Headless Browser
    Open Browser    ${urlHotdog}    Chrome
    ...    options=add_argument("--headless");add_argument("--no-sandbox");add_argument("--disable-dev-shm-usage");add_argument("--disable-gpu");add_argument("--window-size=1920,1080")

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

Navigate To User Management
    # Κλικ στο μενού Διαχείριση
    Wait Until Element Is Visible    xpath=//button[@data-slot='collapsible-trigger' and .//span[text()='Διαχείριση']]    timeout=10s
    Click Element                    xpath=//button[@data-slot='collapsible-trigger' and .//span[text()='Διαχείριση']]
    Sleep    1s
    # Κλικ στο Διαχείριση Χρηστών
    Wait Until Element Is Visible    xpath=//a[@href='/account/manage' and .//span[text()='Διαχείριση Χρηστών']]    timeout=10s
    Click Element                    xpath=//a[@href='/account/manage' and .//span[text()='Διαχείριση Χρηστών']]
    Sleep    2s

Add Admin User
    [Arguments]    ${name}=${newUserName}    ${email}=${newUserEmail}
    # Κλικ στο κουμπί Προσθήκη
    Wait Until Element Is Visible    xpath=//button[@data-slot='sheet-trigger' and contains(., 'Προσθήκη')]    timeout=10s
    Click Element                    xpath=//button[@data-slot='sheet-trigger' and contains(., 'Προσθήκη')]
    Sleep    2s
    # Συμπλήρωση φόρμας — προσάρμοσε τα ids αν διαφέρουν
   # Email field — σίγουρο locator
    Wait Until Element Is Visible    id=email    timeout=10s
    Input Text                       id=email    ${email}

    # Τσεκάρισμα Admin checkbox
    Wait Until Element Is Visible    id=check-0    timeout=5s
    ${checked}=    Get Element Attribute    id=check-0    aria-checked
    Run Keyword If    '${checked}' == 'false'    Click Element    id=check-0
    Sleep    1s
    # Κλικ Αποθήκευση αλλαγών
    Click Element                    xpath=//button[@type='submit' and contains(., 'Αποθήκευση αλλαγών')]
    Sleep    2s
    # Επαλήθευση success toast
    Wait Until Element Is Visible    xpath=//li[@data-sonner-toast and @data-type='success']//div[@data-title and contains(., 'Επιτυχής δημιουργία χρήστη')]    timeout=10s
    # Επαλήθευση ότι ο χρήστης εμφανίζεται στη λίστα με ρόλο Διαχειριστής
    Wait Until Element Is Visible    xpath=//span[contains(text(), '${name}')]    timeout=10s
    Wait Until Element Is Visible    xpath=//span[@data-slot='badge' and contains(., 'Διαχειριστής')]    timeout=5s

Delete User
    [Arguments]    ${name}=${newUserName}
    Wait Until Element Is Visible    xpath=//span[contains(text(), '${name}')]    timeout=10s
    Click Element    xpath=//span[contains(text(), '${name}')]/ancestor::div[contains(@class,'flex')]//button[@data-slot='alert-dialog-trigger']
    Sleep    1s
    Wait Until Element Is Visible    xpath=//button[@data-slot='alert-dialog-action' and contains(., 'Διαγραφή')]    timeout=5s
    Click Element    xpath=//button[@data-slot='alert-dialog-action' and contains(., 'Διαγραφή')]

    # Περιμένουμε πρώτα το success toast
    Wait Until Element Is Visible    xpath=//li[@data-sonner-toast and @data-type='success']    timeout=10s

    # Reload της σελίδας για να ανανεωθεί η λίστα
    Reload Page
    Sleep    2s

    # Τώρα ελέγχουμε ότι ο χρήστης δεν υπάρχει
    Wait Until Element Is Not Visible    xpath=//span[contains(text(), '${name}')]    timeout=15s

*** Test Cases ***
TC1 Login Success
    Do Login
    Sleep   3s
    Close Browser

TC2 Login Wrong Email
    Do Login     email=invalid-email@email.com   password= ${pwd1}
    Wait Until Element Is Visible  xpath=//div[@class='validation-message' and (normalize-space()='Ο κωδικός πρόσβασης δεν είναι σωστός' or normalize-space()='The password is incorrect')]     #xpath=//div[@class='validation-message' and (normalize-space()='Check your email address' or normalize-space()='Έλεγξε τη διεύθυνση email σου')]
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

TC5 Delete And Recreate Admin User
    [Setup]    Do Login
    Select Company    ${companyTIN1}
    Navigate To User Management
    # Βήμα 1: Διαγραφή χρήστη
    Delete User    ${newUserName}
    Sleep    2s
    # Βήμα 2: Δημιουργία χρήστη ξανά
    Add Admin User    ${newUserName}    ${newUserEmail}
    [Teardown]    Close Browser

