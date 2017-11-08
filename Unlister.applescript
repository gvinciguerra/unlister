-- https://github.com/gvinciguerra/unlister

to getUnsubscribeCommands(unsubscribeHeader)
	set awk to " | awk  'NR>1{print $1}' RS='<' FS='>'"
	set result to do shell script "echo " & quoted form of unsubscribeHeader & awk
	return paragraphs of result
end getUnsubscribeCommands

to parseMailtoURL(mailtoURL)
	set quot to quoted form of mailtoURL
	set egrep to " | perl -nle 'print $& if /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,6}/'"
	set recipient to do shell script "echo " & quot & egrep as string
	set sed1 to " | perl -nle 'print $1 if /[&\\?]subject=([^?&]+)/'"
	set subject to do shell script "echo " & quot & sed1 as string
	set sed2 to " | perl -nle 'print $1 if /[&\\?]body=([^?&]+)/'"
	set body to do shell script "echo " & quot & sed2 as string
	return {rcp:recipient, sbj:subject, bdy:body}
end parseMailtoURL

to unsubscribeFrom(subscription, command)
	set commandScheme to scheme of (command as URL)
	if commandScheme is mail URL then
		tell application "Mail"
			set newMail to my parseMailtoURL(command)
			set user to ((name of subscription's recipient) as string) & " <" & address of subscription's recipient & ">"
			if sbj of newMail is "" then set sbj of newMail to " " -- Avoid "this message has no subject" alert
			tell (make new outgoing message with properties {subject:sbj of newMail, sender:user, content:bdy of newMail})
				make new to recipient with properties {address:rcp of newMail}
				send
			end tell
		end tell
		return true
	else if commandScheme is in {secure http URL, http URL} then
		try
			do shell script "curl  -LfS " & command
			return true
		on error e
			log e as string
		end try
	end if
	return false
end unsubscribeFrom

tell application "Mail"
	set titles to {}
	set subscriptions to messages of junk mailbox whose all headers contains "List-Unsubscribe"
	repeat with mail in subscriptions
		set end of titles to mail's sender & ": " & mail's subject & " " & mail's id
	end repeat
	
	set choices to choose from list titles with prompt "Select subscriptions." OK button name {"Unsubscribe"} cancel button name {"Cancel"} with multiple selections allowed
	if choices is false then return
	
	set dialogResult to display dialog "Do you also want to trash the selected mails?" buttons {"Yes", "No"}
	set mustTrash to button returned of dialogResult is "Yes"
	set succeeded to 0
	
	set my progress total steps to length of choices
	set my progress completed steps to 0
	
	repeat with choice in choices
		set subscription to (first message of junk mailbox whose id = last word of choice)
		set unsubscribeHeader to content of subscription's header named "List-Unsubscribe"
		set commands to my getUnsubscribeCommands(unsubscribeHeader)
		set success to false
		
		repeat with command in commands
			set success to my unsubscribeFrom(subscription, command)
			-- if success then exit repeat
		end repeat
		
		if success then
			set succeeded to 1 + succeeded
			if mustTrash then delete subscription
		end if
		set my progress completed steps to 1 + (my progress completed steps)
	end repeat
	
	display alert "Unsubscribed from " & succeeded & "/" & length of choices & " lists."
end tell
