/client/proc/cmd_admin_say(msg as text)
	set category = "Admin"
	set name = "Asay" //Gave this shit a shorter name so you only have to time out "asay" rather than "admin say" to use it --NeoFite
	set hidden = TRUE
	if(!check_rights(0))
		return

	msg = emoji_parse(copytext_char(sanitize(msg), 1, MAX_MESSAGE_LEN))
	if(!msg)
		return

	mob.log_talk(msg, LOG_ASAY)
	msg = keywords_lookup(msg)
	var/asay_color = prefs.read_preference(/datum/preference/color/asay_color)
	var/custom_asay_color = (CONFIG_GET(flag/allow_admin_asaycolor) && asay_color) ? "<font color=[asay_color]>" : "<font color='[DEFAULT_ASAY_COLOR]'>"
	msg = "[span_adminsay("[span_prefix("ADMIN:")] <EM>[key_name(usr, 1)]</EM> [ADMIN_FLW(mob)]: [custom_asay_color]<span class='message linkify'>[msg]")]</span>[custom_asay_color ? "</font>":null]"
	to_chat(GLOB.admins,
		type = MESSAGE_TYPE_ADMINCHAT,
		html = msg,
		confidential = TRUE)

	SSblackbox.record_feedback("tally", "admin_verb", 1, "Asay") //If you are copy-pasting this, ensure the 2nd parameter is unique to the new proc!

/client/proc/get_admin_say()
	var/msg = input(src, null, "asay \"text\"") as text|null
	cmd_admin_say(msg)
