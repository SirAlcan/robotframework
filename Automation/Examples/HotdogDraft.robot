*** Settings ***
Documentation   Hotdog
Library         SeleniumLibrary
Suite Setup     Open Headless Browser
Suite Teardown  Close Browser Session

*** Variables ***
${urlHotdog}      https://hotdoc.impact.gr/
${Browser1}         Chrome
${HEADLESS}         False    # Τοπικά False, στο GitHub True
${userEmail1}     gregkazakou@gmail.com
${pwd1}           Papaki2!
${companyTIN1}    135952929
${newUserName}      Grigoris Kazakou
${newUserEmail}     gkazakou@impact.gr
${INVALID_EMAIL}    mhtsos@something.com

${LOGIN_LINK}    xpath=//a[@href="/auth/login"]
${SEARCH_INPUT}    xpath=//input[@placeholder="Αναζήτηση εταιρίας μέσω ΑΦΜ"]
${SUCCESS_LOGIN_URL}    https://hotdoc.impact.gr/company/select?redirectUrl=/dashboard

${USERNAME_FIELD}    id=emailInput
${PASSWORD_FIELD}    name=LoginInput.Password
${LOGIN_BUTTON}      id=loginButton
${LOGIN_URL}    https://hotdoc.impact.gr/auth/login

${newCompanyName}      LMC Demo
${expectedAadeUser}    LMCNEW2025

${DASHBOARD_LINK}        xpath=//a[@href='/dashboard']//button[@data-slot='sidebar-menu-button']
${INVOICES_LINK}         xpath=//a[@href='/invoices/incoming']//button[@data-slot='sidebar-menu-button']
${PREV_MONTH_BUTTON}     xpath=(//button[@data-slot='button' and @data-variant='outline' and @data-size='icon'])[1]
${MONTH_LABEL}           xpath=//div[contains(@class,'bg-white') and contains(@class,'rounded-md') and contains(text(),'2026') or contains(text(),'2025')]
${CHART_BARS}            xpath=//path[contains(@class,'recharts-rectangle')]
${TOOLTIP_VALUE}         xpath=//div[contains(@class,'recharts-tooltip')]//span[contains(@class,'font-mono')]
${DATE_INPUTS}           xpath=//input[@placeholder='dd/MM/yyyy']
${ROW_COUNT_LABEL}       xpath=//div[contains(text(),'γραμμές επιλεγμένες')]
${LOAD_MORE_ROW}         xpath=//span[normalize-space(.)='Φόρτωση περισσότερων..']

*** Keywords ***
# ======================================
# ---------------- HELPERS -------------
# ======================================
Safe Click
    [Arguments]    ${locator}    ${timeout}=10s

    Wait Until Keyword Succeeds    ${timeout}    500ms
    ...    Run Keywords
    ...    Scroll Element Into View    ${locator}
    ...    AND    Element Should Be Visible    ${locator}
    ...    AND    Element Should Be Enabled    ${locator}
    ...    AND    Click Element    ${locator}

Safe Wait Element
    [Arguments]    ${locator}    ${timeout}=10s

    Wait Until Keyword Succeeds    ${timeout}    500ms
    ...    Run Keywords
    ...    Scroll Element Into View    ${locator}
    ...    AND    Element Should Be Visible    ${locator}
    ...    AND    Element Should Be Enabled    ${locator}

Safe Input Text
    [Arguments]    ${locator}    ${text}    ${timeout}=10s

    Safe Wait Element    ${locator}    ${timeout}
    Clear Element Text   ${locator}
    Input Text           ${locator}    ${text}

Wait For Page Ready
    # Basic “page loaded” check
    Wait Until Page Contains Element    xpath=//body    10s

Expand Menu By Text
    [Arguments]    ${menu_name}

    ${MENU}    Set Variable    xpath=//button[.//span[normalize-space(.)="${menu_name}"]]
    Safe Wait Element    ${MENU}
    ${expanded}=    Get Element Attribute    ${MENU}    aria-expanded
    Run Keyword If    '${expanded}' == 'false'
    ...    Safe Click    ${MENU}

Click Menu Item By Name
    [Arguments]    ${item_name}
    Wait Until Element Is Visible    xpath=//a[normalize-space()="${item_name}"]
    Click Element    xpath=//a[normalize-space()="${item_name}"]
# ======================================
# ---------------- SUITE -------------
# ======================================

Open Headless Browser
    IF    '${HEADLESS}' == 'True'
        Open Browser    ${urlHotdog}    ${Browser1}    options=add_argument("--headless")
    ELSE
        Open Browser    ${urlHotdog}    ${Browser1}
    END
    Maximize Browser Window
    Go To    ${urlHotdog}auth/login
    Wait Until Page Contains Element    ${USERNAME_FIELD}    15s


Open Browser To App
    [Arguments]    ${url}    ${browser}
    Open Browser    ${url}    ${browser}
    Maximize Browser Window

Close Browser Session
    Close All Browsers

# ======================================
# ---------------- LOGIN ---------------
# ======================================
Test Login
    [Arguments]    ${username}    ${password}

    Safe Wait Element    ${USERNAME_FIELD}
    Input Text    ${USERNAME_FIELD}    ${username}
    Safe Click    ${LOGIN_BUTTON}
    Wait Until Element Is Visible    ${PASSWORD_FIELD}
    Input Password    ${PASSWORD_FIELD}    ${password}
    Safe Click    ${LOGIN_BUTTON}

Valid Login Test

    [Arguments]    ${username}    ${password}
    Test Login    ${username}    ${password}
    Wait For Page Ready
    Wait Until Location Is    ${SUCCESS_LOGIN_URL}

# ======================================
# ----------- COMPANY SELECT -----------
# ======================================

Select Company
    [Arguments]    ${companyTIN1}
    Safe Input Text    ${SEARCH_INPUT}     ${companyTIN1}
    Safe Click    xpath=//button[.//span[normalize-space(.)="Επιλογή"]]
    Wait Until Page Contains     επιλέχθηκε    10s
    Wait Until Location Is    https://hotdoc.impact.gr/dashboard
    #Location Should Be    https://hotdoc.impact.gr/dashboard
    ${text}=    Get Text    xpath=//*[contains(., "επιλέχθηκε")]
    Should Match Regexp    ${text}     Η εταιρεία.+επιλέχθηκε

# ======================================
# ----------- USER CONTROL -----------
# ======================================
Navigate To User Management

    Expand Menu By Text    Διαχείριση
    Click Menu Item By Name    Διαχείριση Χρηστών
    Wait Until Location Is    https://hotdoc.impact.gr/account/manage

Delete User
    [Arguments]    ${name}=${newUserName}
    Safe Click     xpath=//span[contains(text(), '${name}')]/ancestor::div[contains(@class,'flex')]//button[@data-slot='alert-dialog-trigger']    timeout=10s
    Safe Click    xpath=//button[@data-slot='alert-dialog-action' and contains(., 'Διαγραφή')]
    # Περιμένουμε πρώτα το success toast
    Wait Until Element Is Visible    xpath=//li[@data-sonner-toast and @data-type='success']    timeout=10s

    # Reload της σελίδας για να ανανεωθεί η λίστα
    Reload Page
    Wait Until Location Is    https://hotdoc.impact.gr/account/manage    10s

    # Τώρα ελέγχουμε ότι ο χρήστης δεν υπάρχει
    Wait Until Element Is Not Visible    xpath=//span[contains(text(), '${name}')]    timeout=15s

Add Admin User
    [Arguments]    ${name}=${newUserName}    ${email}=${newUserEmail}

    Safe Click    xpath=//button[@data-slot='sheet-trigger' and contains(., 'Προσθήκη')]
    Wait Until Page Contains    Προσθήκη Χρήστη    10s
    Safe Input Text    id=email    ${email}
    Safe Wait Element      id=check-0    timeout=5s

    ${checked}=    Get Element Attribute    id=check-0    aria-checked
    Run Keyword If    '${checked}' == 'false'    Click Element    id=check-0

    # Κλικ Αποθήκευση αλλαγών
    Safe Click                    xpath=//button[@type='submit' and contains(., 'Αποθήκευση αλλαγών')]

    # Επαλήθευση success toast
    Wait Until Element Is Visible    xpath=//li[@data-sonner-toast and @data-type='success']//div[@data-title and contains(., 'Επιτυχής δημιουργία χρήστη')]    timeout=10s
    # Επαλήθευση ότι ο χρήστης εμφανίζεται στη λίστα με ρόλο Διαχειριστής
    Wait Until Element Is Visible    xpath=//span[contains(text(), '${name}')]    timeout=10s
    Wait Until Element Is Visible    xpath=//span[@data-slot='badge' and contains(., 'Διαχειριστής')]    timeout=5s
# ======================================
# ----------- CHANGE COMPANY -----------
# ======================================
Change Company
    [Arguments]    ${company_name}=${newCompanyName}

    # Άνοιγμα του dropdown επιλογής εταιρείας στο sidebar
    Safe Click    xpath=//button[@data-slot='dropdown-menu-trigger' and @data-sidebar='menu-button']

    # Περιμένουμε να ανοίξει το menu
    Wait Until Element Is Visible    xpath=//div[@role='menuitem']    timeout=10s

    # Επιλογή της εταιρείας — contains αντί για normalize-space για να πιάσει το text
    Wait Until Element Is Visible    xpath=//div[@role='menuitem'][contains(., '${company_name}')]    timeout=10s
    Click Element                    xpath=//div[@role='menuitem'][contains(., '${company_name}')]

    # Επαλήθευση toast μηνύματος
    Wait Until Element Is Visible
    ...    xpath=//li[@data-sonner-toast]//div[@data-title and contains(., 'Η εταιρεία ${company_name} επιλέχθηκε')]
    ...    timeout=10s

Validate Company Changed
    [Arguments]    ${company_name}=${newCompanyName}    ${aade_user}=${expectedAadeUser}

    # Πλοήγηση στη Διαχείριση Εταιρείας
    Safe Click    xpath=//a[@data-slot='sidebar-menu-sub-button' and @href='/company/manage']
    Wait Until Location Is    https://hotdoc.impact.gr/company/manage    10s

    # 1ος έλεγχος: το πεδίο aadeUsername έχει τιμή LMCNEW2025
    Safe Wait Element    xpath=//input[@name='aadeUsername']
    ${aadeValue}=    Get Element Attribute    xpath=//input[@name='aadeUsername']    value
    Should Be Equal As Strings    ${aadeValue}    ${aade_user}
    ...    msg=Expected aadeUsername to be '${aade_user}' but found '${aadeValue}'

    # 2ος έλεγχος: το όνομα εταιρείας στο sidebar είναι LMC Demo
    Wait Until Element Is Visible
    ...    xpath=(//span[@class='truncate font-medium' and normalize-space(.)='${company_name}'])[1]
    ...    timeout=10s
Click Tallest Bar - First Match
    ${js}=    Catenate    SEPARATOR=\n
    ...    const bars = [...document.querySelectorAll('.recharts-bar-rectangle path')];
    ...    const maxH = Math.max(...bars.map(b => parseFloat(b.getAttribute('height'))));
    ...    const tallest = bars.find(b => parseFloat(b.getAttribute('height')) === maxH);
    ...    tallest.setAttribute('data-robot-target', 'tallest');
    ...    return bars.filter(b => parseFloat(b.getAttribute('height')) === maxH).length;

    ${count}=    Execute Javascript    ${js}
    Log    Found ${count} bar(s) with max height
    Click Element    css:[data-robot-target="tallest"]


# ======================================
# ----------- DASHBOARD FILTERS -----------
# ======================================

Navigate To Dashboard
    Safe Click    ${DASHBOARD_LINK}
    Wait Until Location Is    https://hotdoc.impact.gr/dashboard    10s
    Wait Until Page Contains    Εισερχόμενα παραστατικά    timeout=15s
    Wait For Chart Bars

Go To Previous Month
    ${current_month}=    Get Text    xpath=//div[contains(@class,'bg-white') and contains(@class,'rounded-md px-4')]
    Log    Current month before: ${current_month}
    Safe Click    ${PREV_MONTH_BUTTON}
    Wait Until Keyword Succeeds    10s    500ms
    ...    Verify Month Changed    ${current_month}
    ${new_month}=    Get Text    xpath=//div[contains(@class,'bg-white') and contains(@class,'rounded-md px-4')]
    Log    Current month after: ${new_month}
    Wait For Chart Bars

Wait For Chart Bars
    [Arguments]    ${timeout}=15s
    Wait Until Page Contains Element    ${CHART_BARS}    timeout=${timeout}
    Sleep    1s
Verify Month Changed
    [Arguments]    ${old_month}
    ${current}=    Get Text    xpath=//div[contains(@class,'bg-white') and contains(@class,'rounded-md px-4')]
    Should Not Be Equal    ${current}    ${old_month}

Find Tallest Bar And Get Tooltip Count
    # Παίρνουμε όλες τις μπάρες
    ${bars}=    Get WebElements    ${CHART_BARS}
    ${count}=    Get Length    ${bars}
    Should Be True    ${count} > 0    msg=No bars found in chart

    # Βρίσκουμε την πιο ψηλή (μεγαλύτερο height) — αν ίδιο, κρατάμε την αριστερή (μικρότερο x)
    ${max_height}=    Set Variable    0
    ${tallest_bar}=    Set Variable    ${None}
    ${tallest_x}=    Set Variable    999999

    FOR    ${bar}    IN    @{bars}
        ${height_str}=    Get Element Attribute    ${bar}    height
        ${x_str}=         Get Element Attribute    ${bar}    x
        ${height}=        Convert To Number    ${height_str}
        ${x}=             Convert To Number    ${x_str}

        ${is_taller}=     Evaluate    ${height} > ${max_height}
        ${is_equal_left}=    Evaluate    ${height} == ${max_height} and ${x} < ${tallest_x}

        IF    ${is_taller}
            ${max_height}=    Set Variable    ${height}
            ${tallest_bar}=   Set Variable    ${bar}
            ${tallest_x}=     Set Variable    ${x}
        ELSE IF    ${is_equal_left}
            ${tallest_bar}=   Set Variable    ${bar}
            ${tallest_x}=     Set Variable    ${x}
        END
    END

    Log    Tallest bar height: ${max_height}, x: ${tallest_x}

    # Hover πάνω στη μπάρα για να εμφανιστεί το tooltip
    Mouse Over    ${tallest_bar}
    Wait Until Element Is Visible    xpath=//div[contains(@class,'recharts-tooltip-wrapper')]//*[contains(text(),'Παραστατικά') or contains(text(),'παραστατικά')]    timeout=5s
    Sleep    500ms    # σταθεροποίηση tooltip

    # Παίρνουμε τον αριθμό από το tooltip
    ${tooltip_text}=    Get Text    xpath=//div[contains(@class,'recharts-tooltip-wrapper')]
    Log    Tooltip text: ${tooltip_text}

    # Extract του αριθμού (πρώτος αριθμός που βρίσκουμε στο tooltip)
    ${count_value}=    Evaluate    re.search(r'\\d+', """${tooltip_text}""").group(0)    modules=re

    # Click στη μπάρα
    Click Element    ${tallest_bar}

    RETURN    ${count_value}

Verify Date Filter Matches Bar
    # Διαβάζουμε τα δύο date inputs και επιβεβαιώνουμε ότι έχουν την ίδια τιμή
    Wait Until Element Is Visible    ${DATE_INPUTS}    timeout=10s
    ${date_elements}=    Get WebElements    ${DATE_INPUTS}
    ${count}=    Get Length    ${date_elements}
    Should Be True    ${count} >= 2    msg=Expected at least 2 date inputs, found ${count}

    ${date_from}=    Get Element Attribute    ${date_elements}[0]    value
    ${date_to}=      Get Element Attribute    ${date_elements}[1]    value

    Log    Date from: ${date_from} | Date to: ${date_to}
    Should Be Equal As Strings    ${date_from}    ${date_to}
    ...    msg=Date range filter mismatch: from=${date_from}, to=${date_to}

    RETURN    ${date_from}

Verify Default Filters On Invoices Page
    Safe Click    ${INVOICES_LINK}
    Wait Until Location Is    https://hotdoc.impact.gr/invoices/incoming    10s
    Wait Until Element Is Visible    xpath=//input[@placeholder='ΤΔΑ']    timeout=15s

    # Σειρά - input value=""
    ${seira}=    Get Element Attribute    xpath=//input[@placeholder='ΤΔΑ']    value
    Should Be Empty    ${seira}    msg=Σειρά should be empty by default but was '${seira}'

    # Αριθμός - input value=""
    ${arithmos}=    Get Element Attribute    xpath=//input[@placeholder='52']    value
    Should Be Empty    ${arithmos}    msg=Αριθμός should be empty by default but was '${arithmos}'

    # ΑΦΜ - input value=""
    ${vat}=    Get Element Attribute    xpath=//input[@name='vat']    value
    Should Be Empty    ${vat}    msg=ΑΦΜ should be empty by default but was '${vat}'

    # invoiceType select - "Όλα"
    ${invoice_type}=    Get Selected List Value    name=invoiceType
    Should Be Equal    ${invoice_type}    all    msg=invoiceType default should be 'all'

    # isDeliveryNote combobox - "Όλα"
    ${delivery_note}=    Get Text    xpath=//button[@id='isDeliveryNote']//span[@data-slot='select-value']
    Should Be Equal    ${delivery_note}    Όλα    msg=isDeliveryNote default should be 'Όλα'

    # invoiceStatus combobox - "Όλα"
    ${status}=    Get Text    xpath=//button[@id='invoiceStatus']//span[@data-slot='select-value']
    Should Be Equal    ${status}    Όλα    msg=invoiceStatus default should be 'Όλα'

    # archived combobox - "Όλα"
    ${archived}=    Get Text    xpath=//button[@id='archived']//span[@data-slot='select-value']
    Should Be Equal    ${archived}    Όλα    msg=archived default should be 'Όλα'

Get Total Rows From Counter
    Wait Until Element Is Visible    ${ROW_COUNT_LABEL}    timeout=15s
    ${counter_text}=    Get Text    ${ROW_COUNT_LABEL}
    Log    Counter text: ${counter_text}

    # "0 από X γραμμές επιλεγμένες" → παίρνουμε το X (τον δεύτερο αριθμό)
    ${total_rows}=    Evaluate    re.search(r'από\\s+(\\d+)', """${counter_text}""").group(1)    modules=re
    RETURN    ${total_rows}

Load All Rows
    # Συνεχίζουμε να κάνουμε scroll/click μέχρι να εξαφανιστεί το "Φόρτωση περισσότερων.."
    FOR    ${i}    IN RANGE    20
        ${has_load_more}=    Run Keyword And Return Status
        ...    Element Should Be Visible    ${LOAD_MORE_ROW}

        IF    not ${has_load_more}    BREAK

        Scroll Element Into View    ${LOAD_MORE_ROW}
        Click Element    ${LOAD_MORE_ROW}
        Sleep    1s    # αναμονή για το loading
        Wait Until Keyword Succeeds    15s    500ms
        ...    Wait For Load More Resolved
    END

Wait For Load More Resolved
    # Επιστρέφει επιτυχία αν δεν υπάρχει πια το loading state
    ${still_loading}=    Run Keyword And Return Status
    ...    Element Should Be Visible    xpath=//*[contains(text(),'Φόρτωση')]
    Should Not Be True    ${still_loading}
*** Test Cases ***
TC 01 - Login Success
    Valid Login Test    ${userEmail1}    ${pwd1}

TC 02 - Select Company Success
    Select Company    ${companyTIN1}

TC 03 - Delete And Recreate Admin User
    Navigate To User Management
    Delete User    ${newUserName}
    Add Admin User    ${newUserName}    ${newUserEmail}
TC 04 - Change Company
    Change Company    ${newCompanyName}
    Validate Company Changed    ${newCompanyName}    ${expectedAadeUser}
TC 05 - Dashboard Filters Check
    Navigate To Dashboard
    Go To Previous Month
    # Click στην ψηλότερη μπάρα και πάρε το count από tooltip
    ${bar_count}=    Find Tallest Bar And Get Tooltip Count
    Log    Bar count from tooltip: ${bar_count}
    # Έλεγξε ότι τα date inputs έχουν ίδια τιμή (μία μέρα)
    ${selected_date}=    Verify Date Filter Matches Bar
    Log    Selected date: ${selected_date}
    # Πήγαινε στο Παραστατικά και επιβεβαίωσε default filters
    Verify Default Filters On Invoices Page
    # 1ος έλεγχος: count μπάρας vs γραμμές πίνακα (πριν load more)
    ${initial_rows}=    Get Total Rows From Counter
    Log    Initial total rows: ${initial_rows}
    # Αν υπάρχει "Φόρτωση περισσότερων..", φόρτωσε όλες
    Load All Rows
    # 2ος έλεγχος: count μπάρας == συνολικές γραμμές
    ${final_rows}=    Get Total Rows From Counter
    Log    Final total rows: ${final_rows}
    Should Be Equal As Integers    ${final_rows}    ${bar_count}
    ...    msg=Bar count (${bar_count}) does not match table rows (${final_rows})