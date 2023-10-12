Refer to the Wiki for the latest updates: https://github.com/the-wozz/jamf_laps/wiki

# What 'Woz' Jamf LAPS does:

Checks for Jamf Pro LAPS information on a machine via serial number, then proceeds to prompt LAPS information to the user. All done through a Jamf API 'client' configured within Jamf 'API Roles and Clients'. Prompts can be via 'IBM Notifier' or 'Swift Dialog'.

A lot of "fail-safes" contained within, automatic finding of the Jamf Pro URL, and customizable settings from the icon to automatic downloading of the notification tool via a Jamf Pro policy trigger. See below for more information.

Swift Dialog prompt:
<img width="727" alt="Screenshot 2023-10-11 at 12 01 30 PM" src="https://github.com/the-wozz/jamf_laps/assets/18219155/a0acafc4-004d-4e5c-97f3-9f515e95b6ff">


## How to use 'Woz' Jamf LAPS:
Recommended way to use is a Jamf Policy 'ongoing' that runs this script with availability through Self Service for a Desk Side Tech (controlled access!).

**Requirements**:
* macOS 11.x or later
* Jamf Pro 10.48 or higher
* [IBM Notifier](https://github.com/IBM/mac-ibm-notifications) and/or [Swift Dialog](https://github.com/swiftDialog/swiftDialog)
* Jamf Local Administrator Password Solution [LINK](https://learn.jamf.com/bundle/technical-paper-laps-current/page/Local_Administrator_Password_Solution.html)
* Jamf Pro API Roles and Clients configured [LINK](https://learn.jamf.com/bundle/jamf-pro-documentation-current/page/API_Roles_and_Clients.html)
**with** the following Privileges:
<img width="1149" alt="Screenshot 2023-10-12 at 7 11 50 AM" src="https://github.com/the-wozz/jamf_laps/assets/18219155/66b591f8-5819-43e0-b4f8-591c8f1f0df2">


### Must configure settings within the script:
* `apiAccount="PUTYOURCLIENTIDHERE"`
* `apiPassword="PUTYOURCLIENTSECRETHERE"`

### Customizable Settings:

**All options/locations should be between the quotations!**

IBM Notifier location, using S.U.P.E.R.M.A.N built-in IBM Notifier location for ease of use
* `ibmNotifier="/Library/Management/super/IBM Notifier.app/Contents/MacOS/IBM Notifier"`

Swift Dialog bin location, default Swift Dialog bin location
* `swiftDialog="/usr/local/bin/dialog"`

Set location of desired image to set notification icon for BOTH notification tools. Refer to the notification tools documentation on what file types are accepted. PNG is always a safe bet to use.
* `notificationIcon="/Location/filename.png"`

Set notification tool choice (1=IBM Notifier 2=Swift Dialog, blank will result in 1)
* `toolChoice="2"`

Shows some detailed info in Terminal output, helpful when troubleshooting
* `verboseMode="0"`

Automatically finds Jamf Pro URL and configures LAPS to use it
[0 = disabled, 1 = enabled, default is 0]
This is done by looking for the Jamf Plist on the machine that the script is executed from. If no Jamf Plist is found, it will prompt the user for the COMPANY name of the Jamf Pro URL.
If you prefer to provide your own url, you can set this to 0 and then define your JSS information in the jamfProURL variable.
* `autoFindURL="1"`

Jamf Pro Policy trigger for IBM Notifier pkg
* `ibmPolicy=""`

Jamf Pro Policy trigger for Swift Dialog pkg
* `swiftPolicy=""`

Timer to display LAPS results, valid for BOTH tools, timer is calculated in seconds, displayed in minutes:seconds
* `popupTimer="900"`
