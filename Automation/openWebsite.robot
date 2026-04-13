*** Settings ***
Documentation   testLogin
Library  SeleniumLibrary
Test Setup   Open the url
Test Teardown  Close Browser
Resource  resource.robot


*** Variables ***


*** Test Cases ***
s1ecosportal
  s1ecosportal Login code


*** Keywords ***
s1ecosportal Login code
   Maximize Browser Window
   Set Selenium Implicit Wait   ${time}
   Input Text  name:FormModel.Email   ${user1}
   Input Text  name:FormModel.Password   ${pwd1}
   Click Element     xpath=//button[text()='Sign In']