*** Settings ***
Library  SeleniumLibrary

*** Variables ***


*** Test Cases ***

AmazonWebSite
   Open Browser  https://www.amazon.com/    Chrome
   Sleep  5
   Close Browser  



*** Keywords ***
