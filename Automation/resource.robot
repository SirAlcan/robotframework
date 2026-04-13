*** Settings ***
Documentation    Test case  to login demo portal
Library  SeleniumLibrary

*** Variables ***
${urlPortal}  https://einvoice-demo-portal.s1ecos.gr/Accounts/Login?lang=en
${uatAPI}  https://einvoiceapiuat.impact.gr/
${Browser}  Chrome
${time}  10seconds
${user1}  gkazakou@impact.gr
${pwd1}  31101995vatr@G
${user2}  gregkazakou@gmail.com
${pwd2}  31101995vatr@G

*** Keywords ***
Open the url
     Open Browser  ${urlPortal}    ${Browser}