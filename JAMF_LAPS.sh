#!/bin/bash

# What it do: Check for LAPS capable accounts on machine via Serial Number, then proceeds to view LAPS for the inputted machine. Done through API account with 'Roles and Clients'. Notifications can be done via 'IBM Notifier' or 'Swift Dialog'. Swift is more asthetically pleasing to the eye. IBM and Swift downloads are done through Jamf Policies NOT github
# Author: Zachary 'Woz'nicki
# Inspired by Brian Oanes
# version: 0.8
# First started: 10/4/23
# Latest update: 11/8/23 9:15 AM PST

## Future/Completed Plans:
# - Check LAPS settings before proceeding | DONE | 10/10/23
# - Ask for input of serial # to convert serial # to Jamf 'Management ID' for easier use (in lieu of asking for 'Computer Management ID') | DONE | 10/5/23
# - Check if LAPS result is valid, if not, show 'cleaner' error message instead of 401 error | DONE | 10/10/23
# - Check if jamf plist is found, if not, prompt user for Jamf URL | DONE | 10/6/23
# - Utilize ability to download IBM Notifier automagically if not found | DONE | 10/6/23
# - Added Swift Dialog as an option and the ablity to choose between notification tools | DONE | 10/10/23
# - Add 'verbose' variable to show more detailed output in Terminal | DONE | 10/10/23
# - autoconfigure Jamf Pro URL (except for company name) | DONE | 10/11/23
# + show ALL available LAPS accounts

### HOW TO USE ###
# Edit Lines 27 (apiAccount) AND 28 (apiPassword) [after the = ] for the 'API Roles and Clients' info

## API Variables ##

# Jamf Pro URL
jamfProURL=
# API 'Roles and Clients' client ID
apiAccount=""
# API 'Roles and Clients' secret
apiPassword=""

# Local Variables
# Machine serial number
sn=$(system_profiler SPHardwareDataType | awk '/Serial/ {print $4}')
bearerToken=""

# Notification Tool Variables

# IBM Notifier location, using S.U.P.E.R.M.A.N built-in IBM Notifier location for ease of use
ibmNotifier="/Library/Management/super/IBM Notifier.app/Contents/MacOS/IBM Notifier"
# Swift Dialog bin location
swiftDialog="/usr/local/bin/dialog"
# Swift Dialog URL
swiftDialogURL="https://github.com/swiftDialog/swiftDialog/releases/download/v2.3.2/dialog-2.3.2-4726.pkg"
# Swift Dialog version
swiftVersion=$(dialog --version | cut -c1-5)
# Set Parameter # to set notiifcation icon for BOTH notification tools
notificationIcon=""
# Set Parameter # to set notification tool choice (1=IBM Notifier 2=Swift Dialog, default is 1=IBM Notifier)
toolChoice="2"
# Shows some detailed info in Terminal output
verboseMode="0"
# Automatically finds Jamf Pro URL configures LAPS to use [0 = disabled, 1 = enabled, default is 0], this will overwrite the 'static' jamfProURL above!
autoFindURL="1"
# Jamf Pro Policy trigger for IBM Notifier pkg
ibmPolicy=""
# Jamf Pro Policy trigger for Swift Dialog pkg
swiftPolicy=""
# Timer to display LAPS results, valid for BOTH tools, timer is calculated in seconds, displayed in minutes:seconds
popupTimer="900"
# Set LAPS accounts to show
managementAccount=""
mdmAccount=""
## End Variables ##

## Functions Start ##
# Check for Jamf Pro plist
checkPlist() {
plistCheck=$(defaults read /Library/Preferences/com.jamfsoftware.jamf.plist | plutil -extract jss_url raw -| rev | cut -c 2- | rev)
    if [[ -n "$plistCheck" ]]; then
        echo "Jamf Pro Plist found!"
        jamfProURL="$plistCheck"
        echo "Jamf Pro URL: $jamfProURL"
        notificationTool
    else
        echo "Jamf Pro Plist NOT found!"
            if [[ "$toolChoice" == "1" ]]; then
                echo "Asking user for Jamf Pro URL via IBM Notifier.."
                jamfProUrlInput=$("$ibmNotifier" -type popup -icon_path "$notificationIcon" -subtitle "Please input Jamf Pro URL" -accessory_view_type input -accessory_view_payload "/placeholder https://COMPANY.jamfcloud.com /required" -main_button_label "Submit")
                echo "User inputted Jamf Pro URL: $jamfProUrlInput"
                jamfProURL="https://$jamfProUrlInput.jamfcloud.com"
                echo "FULL URL:$jamfProURL"
                notificationTool
            elif [[ "$toolChoice" == "2" ]]; then
                echo "Asking user for Jamf Pro URL via Swift Dialog.."
                jamfProUrlInput=$("$swiftDialog" -i "$notificationIcon" -o -p -s -t "Jamf Pro URL Needed" --messagefont size="15" -m "Input Jamf Pro URL" --textfield "Jamf Pro URL",prompt="https://COMPANY.jamfcloud.com",required --button1text "Submit" --button2text "Exit")
                    case $? in
                        0)
                            newURL=$(echo "$jamfProUrlInput" | awk '{print $5}')
                            echo "User inputted Jamf Pro URL: $newURL"
                            jamfProURL=https://"$newURL".jamfcloud.com
                            echo "FULL URL:$jamfProURL"
                            notificationTool
                        ;;
                        2)
                            echo "User pressed Exit button"
                            exit 0
                        ;;
                        *)
                            echo "IDK wat hapeded"
                        ;;
                    esac
                
            fi
    fi
}

notificationTool() {
if [[ -z "$toolChoice" ]]; then
    echo "* No tool was selected! *" 
    echo "Defaulting to: Swift Dialog"
    toolChoice="2"
fi
if [[ "$toolChoice" == "1" ]]; then
    echo "Notification Tool selected: IBM Notifier"
    echo "Checking for IBM Notifier installation..."
    checkIbmNotifier
elif [[ "$toolChoice" == "2" ]]; then
    echo "Notification Tool selected: Swift Dialog"
    echo "Checking for Swift Dialog installation..."
    checkSwiftDialog
fi
}

checkIbmNotifier() {
    if  [[ -z "$ibmPolicy" ]]; then
        echo "WARNING: *** Jamf Pro policy for IBM Notifier download NOT set! ***"
    fi
if [[ -e "$ibmNotifier" ]]; then
    echo "IBM Notifier Found. Continuing..."
    getSerialNumber
elif [[ -n "$ibmPolicy" ]] && [[ ! -e "$ibmNotifier" ]]; then
    echo "IBM Notifier NOT Found!"
    echo "Calling Jamf Pro policy: $ibmPolicy"
    jamf policy -event "$ibmPolicy"
    wait
    getSerialNumber
elif [[ -z "$ibmPolicy" ]] && [[ ! -e "$ibmNotifier" ]]; then
    echo "*** ERROR: IBM Notifier Jamf Policy NOT set AND can NOT locate IBM Notifier ***"
    echo "Exiting.."
    exit 1
fi
}

checkSwiftDialog() {
    if [[ -z "$swiftPolicy" ]]; then
        echo "WARNING: *** Jamf Pro policy for Swift Dialog download NOT set! ***"
    fi
    if [[ -z "$swiftDialogURL" ]]; then
        echo "WARNING: *** Swift Dialog download URL NOT set! ***"
    fi
if [[ -e "$swiftDialog" ]]; then
    echo "Swift Dialog Found. Continuning..."
        if [[ "$swiftVersion" > "2.3.0" ]]; then
            echo "Swift Dialog version is: $swiftVersion"
            echo "Proceeeding.."
            getSerialNumber
        elif [[ "$swiftVersion" < "2.3.0" ]]; then
            echo "WARNING: Swift Dialog version is: $swiftVersion"
            echo "Version too old! Version 2.3.x or higher is required"
            echo "Removing and downloading newer version..."
            pkill -HUP Dialog
            rm -rf "/Library/Application Support/Dialog"
            rm -rf "$swiftDialog"
            getSwiftDialog
        fi
elif [[ -n "$swiftPolicy" ]] && [[ ! -e "$swiftDialog" ]]; then
    echo "Swift Dialog NOT Found!"
	echo "Downloading Swift Dialog (from GH)"
    getSwiftDialog
#    echo "Calling Jamf Pro policy: $swiftPolicy"
#    jamf policy -event "$swiftPolicy"
elif [[ -z "$swiftPolicy" ]] && [[ ! -e "$swiftDialog" ]]; then
    echo "*** WARNING: Swift Dialog Jamf Policy NOT set AND can NOT locate Swift Dialog ***"
    echo "Falling back to IBM Notifier!"
    toolChoice="1"
    checkIbmNotifier
fi
}

# Download and install the Swift Dialog
getSwiftDialog() {
temp_file="/Library/Application Support/JAMF/Waiting Room/sDtemp.pkg"
curl --location "${swiftDialogURL}" --output "$temp_file" 2>&1
wait
if [[ -f "${temp_file}" ]]; then
    installer -pkg "${temp_file}" -target /
	    if [[ -e "$swiftDialog" ]]; then
            echo "Swift Dialog found! Version: $swiftVersion"
            echo "Continuing..."
	    else
		    echo "Error: Unable to install Swift Dialog?"
	    fi
else
	echo "Error: Unable to download Swift Dialog from: ${swiftDialogURL}"
fi
rm -Rf "${temp_file}" > /dev/null 2>&1
getSerialNumber
}


# Get Bearer Token for API calls via 'API Roles and Clients' 
# NEW! Different from developer.jamf.com 'Recipes'
# Token is only valid for 60 seconds for securitay
getBearerToken() {
    response=$(curl -s -L -X POST "$jamfProURL"/api/oauth/token \
                    -H 'Content-Type: application/x-www-form-urlencoded' \
                    --data-urlencode "client_id=$apiAccount" \
                    --data-urlencode 'grant_type=client_credentials' \
                    --data-urlencode "client_secret=$apiPassword")
    bearerToken=$(echo "$response" | plutil -extract access_token raw -)
if [[ "$verboseMode" == "1" ]]; then
    echo "Bearer Token: $bearerToken"
fi
}

# Get LAPS MDM settings in the environment (only visible in Terminal and Jamf logs)
lapsMDMCheck() {
    if [[ "$verboseMode" == "1" ]]; then
lapsStatus=$(curl -s -X GET "$jamfProURL"/api/v2/local-admin-password/settings \
     -H 'accept: application/json' \
     -H "Authorization: Bearer ${bearerToken}")
lapsStatus2=$(echo "$lapsStatus" | plutil -extract autoDeployEnabled raw -)
    echo "LAPS MDM Status: $lapsStatus2"
# if [[ "$lapsStatus2" == "false" ]]; then
#         echo "LAPS MDM Not Enabled in environment!"
#         echo "Prompting user on LAPS fault."
#             if [[ "$toolChoice" == "2" ]]; then
#                 "$swiftDialog" -i "$notificationIcon" --style "caution" -p --title "LAPS Issue" --messagefont size="13" -m "LAPS MDM is not enabled on this device."
#                 exit 0
#             elif [[ "$toolChoice" == "1" ]]; then
#                 "$ibmNotifier" -type SystemAlert -icon_path "$notificationIcon" -title "LAPS Issue" -subtitle "LAPS MDM is not enabled on this device." -main_button_label "OK"
#                 exit 0
#             fi
# else
#         echo "LAPS MDM: Enabled in environment. Continuing.."
#         getManagementID
# fi
    else
        getManagementID
fi
}

# Ask for machine serial number then validate the machine
getSerialNumber() {
if [[ "$toolChoice" == "1" ]]; then
    echo "Prompting for serial number via IBM Notifier"
    inputSerialNumber=$("$ibmNotifier" -type popup -icon_path "$notificationIcon" -subtitle "Input machine serial number to view LAPS account and password." -accessory_view_type input -accessory_view_payload "/placeholder Computer Serial Number /required" -main_button_label "Submit" -secondary_button_label "Exit" -secondary_button_cta_type none )
    cleanSerial=$(echo "$inputSerialNumber" | tr -d ' ')
    serialLength=${#cleanSerial}
        if [[ "$verboseMode" == "1" ]]; then
            echo "Serial number length is: $serialLength"
        fi
        if [[ -z "$inputSerialNumber" ]]; then
            echo "User pressed Exit button"
            exit 0
        fi
        if [[ "$serialLength" -lt "10" ]] || [[ "$serialLength" -gt "12" ]]; then
           echo "User inputted incorrect serial number!"
            echo "Serial Number inputted: $cleanSerial"
           echo "Serial number length was under 10 or over 12"
           echo "Prompting again.."
           "$ibmNotifier" -type SystemAlert -icon_path "$notificationIcon" -title "Incorrect serial number" -subtitle "Serial number length is between 10-12 characters." -main_button_label "OK"
           getSerialNumber
        else
            echo "Serial Number inputted: $cleanSerial"
            getBearerToken
            validMachine
        fi
elif [[ "$toolChoice" == "2" ]]; then
    echo "Prompting for serial number via Swift Dialog"
    inputSerialNumber=$("$swiftDialog" -i "$notificationIcon" -o -p -s --helpmessage "If machine does not return results, please open a Remedy ticket for Jamf Suppport Team.  \nhttps://mastercard-smartit.onbmc.com/smartit/app/#/create/incidentPV" -t "Jamf LAPS" --messagefont size="15" -m "Input any Managed Mac serial number to view LAPS information" --textfield "Serial Number",prompt="$sn",regex="^^[[:alnum:]]{10}$|^[[:alnum:]]{12}$",regexerror="Serial number must be 10-12 characters" --button1text "Submit" --button2text "Exit")
        case $? in
            0)
                input2=$(echo "$inputSerialNumber" | awk '{print $4}'| tr -d ' ')
                if [[ -z "$input2" ]]; then
                cleanSerial=$sn
                echo "No serial inputted, using machine serial: $sn"
                else
                cleanSerial=$(echo "$inputSerialNumber" | awk '{print $4}'| tr -d ' ')
                echo "Serial Number inputted: $cleanSerial"
                fi
                getBearerToken
                validMachine
            ;;
            2)
                echo "User pressed Exit button"
                exit 0
            ;;
            *)
                echo "IDK wat hapeded"
            ;;
        esac
fi
}

# Converts inputted machine serial number to machine ID to manamagement ID...only way to view a LAPS account and password is via management ID
getManagementID() {
machineSerial=$(curl -s -X GET "$jamfProURL"/JSSResource/computers/serialnumber/"$cleanSerial" \
     -H 'accept: application/json' \
     -H "Authorization: Bearer ${bearerToken}" )
     machineID=$(echo "$machineSerial" | plutil -extract "computer"."general"."id" raw -)
         echo "Machine ID: $machineID"
     managementID=$(curl -s -X GET "$jamfProURL/api/v1/computers-inventory-detail/$machineID" \
     -H 'accept: application/json' \
     -H "Authorization:Bearer ${bearerToken}" | plutil -extract "general"."managementId" raw -)
    if [[ "$verboseMode" == "1" ]]; then 
        echo "Management ID: $managementID"
    fi
lapsCapableAccounts
}

validMachine() {
responseCode=$(curl -s -w "%{http_code}" -X GET "$jamfProURL"/JSSResource/computers/serialnumber/"$cleanSerial" -o /dev/null \
    -H 'accept: application/json' \
    -H "Authorization: Bearer ${bearerToken}")
    if [[ "$verboseMode" == "1" ]]; then 
        echo "HTTP RESPONSE CODE: $responseCode"
    fi
    if [[ ${responseCode} == 200 ]]; then
        echo "Serial number found. Continuing.."
        lapsMDMCheck
    else
        echo "Serial number NOT found!"
            if [[ "$toolChoice" == "1" ]]; then
                echo "Invalid serial prompting via IBM Notifier"
                "$ibmNotifier" -type SystemAlert -icon_path "$notificationIcon" -title "Serial Number Not Found" -subtitle "Could not locate serial number within Jamf Pro." -main_button_label "OK"
#                getSerialNumber # Uncomment line to be reprompted on error
                exit 0
            elif [[ "$toolChoice" == "2" ]]; then
                echo "Invalid serial prompting via Swift Dialog"
                "$swiftDialog" --default_popup_icon_path "$notificationIcon" --style "caution" -p --title "Invalid Serial Number" --messagefont size="13" -m "Could not locate serial number within Jamf Pro.    \n  \nJamf Pro URL:  \n$jamfProURL"
#                getSerialNumber # Uncomment line to be reprompted on error
                exit 0
            fi
    fi
}

# LAPS capable account(s)
# Only showing the management account currently! MDM option to be supported in later release
lapsCapableAccounts() {
lapsAccounts=$(curl -s -X GET "$jamfProURL"/api/v2/local-admin-password/"$managementID"/accounts \
     -H 'accept: application/json' \
     -H "Authorization: Bearer ${bearerToken}")
# Gets total number of LAPS accounts
totalAccounts=$(echo "$lapsAccounts" | plutil -extract "totalCount" raw -)
    echo "Total LAPS account(s): $totalAccounts"
#lapsAccounts2=$(echo "$lapsAccounts" | plutil -extract results.0.username raw -)
    getLAPSPassword
}

# Obtain Management Account LAPS Password via API
getLAPSPassword() {
lapsPass=$(curl -s -X GET "$jamfProURL"/api/v2/local-admin-password/"$managementID"/account/"$managementAccount"/password \
     -H 'accept: application/json' \
     -H "Authorization: Bearer ${bearerToken}")
cleanPass=$(echo "$lapsPass" | awk '{print $3}' | tr -d '"')
    if [[ "$verboseMode" == "1" ]]; then 
            echo "PW: $cleanPass"
    fi
        if [[ "$popupTimer" == "P" ]]; then
            echo "* Setting popup Timer to same time as Jamf LAPS password validation time *"
            passwordTime
            popupTimer="$difference"
        fi
    if [[ "$totalAccounts" -gt 1 ]]; then
        getMDMPassword
    else
        cleanPass2="Not Available"
        passwordResults
    fi
}

getMDMPassword() {
secondLAPS=$(curl -s -X GET "$jamfProURL"/api/v2/local-admin-password/"$managementID"/account/"$mdmAccount"/password \
     -H 'accept: application/json' \
     -H "Authorization: Bearer ${bearerToken}")
cleanPass2=$(echo "$secondLAPS" | awk '{print $3}' | tr -d '"')
    if [[ "$verboseMode" == "1" ]]; then 
        echo "PW: $cleanPass2"
    fi
        passwordResults
}

passwordResults() {
#    passwordTime
echo "Password being displayed for $popupTimer seconds"
    if [[ "$toolChoice" == "1" ]]; then
        "$ibmNotifier" -type popup -icon_path "$notificationIcon" -title "LAP information for $inputSerialNumber:" -accessory_view_type timer -accessory_view_payload "Username: $lapsAccounts2  
Password: $cleanPass

    Time until message is removed: %@" -timeout "$popupTimer" -main_button_label "Aknowledged" -main_button_cta_type none
    elif [[ "$toolChoice" == "2" ]]; then
        "$swiftDialog" -i "$notificationIcon" -s -o -p -t "Jamf LAPS for $cleanSerial" --messagefont size="14" -m "Username: $managementAccount  \nPassword: $cleanPass  \n  \nUsername: $mdmAccount  \nPassword: $cleanPass2" --timer "$popupTimer" --button1text "OK" --helpmessage "If 'Not Available' is displayed for an account, that account is not currently LAPS enabled."
    fi
exit 0
}

# Future Idea | Match Password display time to the time the password is available before rotation
passwordTime() {
passwordHistory=$(curl -s -X GET "$jamfProURL"/api/v2/local-admin-password/"$managementID"/account/"$lapsAccounts2"/history \
    -H 'accept: application/json' \
    -H "Authorization: Bearer ${bearerToken}")
checkPassTime=$(echo "$passwordHistory" | grep "expirationTime" | sed -n 2p | awk '{print $3}'| tr -d '",' | cut -f1,2 -d':' | cut -d'T' -f2-)
checkPassTime2=$(date -d "$checkPassTime" +%s)
machineDate=$(echo "`date -u` `date +%s`" | awk '{print $4}' | cut -f1,2 -d':')
machineDate2=$(echo "`date -u`" `"$machineDate" +%s`)
echo $machineDate
difference=$(( "$checkPassTime2" - "$machineDate2" ))
# if [[ "$verboseMode" == "1" ]]; then
    echo "Password Good until: $checkPassTime | Machine Time: $machineDate"
    echo "Difference: $difference seconds"
#fi
}
## End Functions ##

## Start execution of script ##
# Check if 'autoFindURL' variable is set to auto find Jamf Plist and populate URL
if [[ "$autoFindURL" == "1" ]]; then
    echo "*** Automatically find Jamf Pro Plist ENABLED ***"
    checkPlist
fi

# Check if verbose mode is enabled
if [[ "$verboseMode" == "1" ]]; then
    echo "*** Verbose Mode ENABLED ***"
fi

notificationTool

exit 0
