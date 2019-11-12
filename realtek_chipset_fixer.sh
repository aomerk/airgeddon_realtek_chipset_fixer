#!/usr/bin/env bash

#Global shellcheck disabled warnings
#shellcheck disable=SC2034

plugin_name="Realtek chipset fixer"
plugin_description="A plugin to fix some problematic Realtek chipsets like RTL8812AU and others"
plugin_author="OscarAkaElvis"

plugin_enabled=1

plugin_minimum_ag_affected_version="10.0"
plugin_maximum_ag_affected_version=""
plugin_distros_supported=("*")

#Custom var needed over all the plugin
realtek_chipset_regexp=".*Realtek.*RTL88.*"

#Override for check_monitor_enabled function to detect correctly monitor mode
function realtek_chipset_fixer_override_check_monitor_enabled() {

	debug_print

	mode=$(iwconfig "${1}" 2> /dev/null | grep Mode: | awk '{print $4}' | cut -d ':' -f 2)

	current_iface_on_messages="${1}"

	if [[ ${mode} != "Monitor" ]]; then
		mode=$(iwconfig "${1}" 2> /dev/null | grep Mode: | awk '{print $1}' | cut -d ':' -f 2)
		if [[ ${mode} != "Monitor" ]]; then
			return 1
		fi
	fi
	return 0
}

#Override for check_interface_mode function to detect correctly card modes
#shellcheck disable=SC2154
function realtek_chipset_fixer_override_check_interface_mode() {

	debug_print

	current_iface_on_messages="${1}"
	if ! execute_iwconfig_fix "${1}"; then
		ifacemode="(Non wifi card)"
		return 0
	fi

	modemanaged=$(iwconfig "${1}" 2> /dev/null | grep Mode: | cut -d ':' -f 2 | cut -d ' ' -f 1)

	if [[ ${modemanaged} = "Managed" ]]; then
		ifacemode="Managed"
		return 0
	fi

	modemonitor=$(iwconfig "${1}" 2> /dev/null | grep Mode: | awk '{print $4}' | cut -d ':' -f 2)

	if [[ ${modemonitor} = "Monitor" ]]; then
		ifacemode="Monitor"
		return 0
	else
		modemonitor=$(iwconfig "${1}" 2> /dev/null | grep Mode: | awk '{print $1}' | cut -d ':' -f 2)
		if [[ ${modemonitor} = "Monitor" ]]; then
			ifacemode="Monitor"
			return 0
		fi
	fi

	language_strings "${language}" 23 "red"
	language_strings "${language}" 115 "read"
	exit_code=1
	exit_script_option
}

#Override for set_chipset to add read_only feature to read the chipset for an interface without modifying chipset var
function realtek_chipset_fixer_override_set_chipset() {

	debug_print

	chipset=""
	sedrule1="s/^[0-9a-f]\{1,4\} \|^ //Ig"
	sedrule2="s/ Network Connection.*//Ig"
	sedrule3="s/ Wireless.*//Ig"
	sedrule4="s/ PCI Express.*//Ig"
	sedrule5="s/ \(Gigabit\|Fast\) Ethernet.*//Ig"
	sedrule6="s/ \[.*//"
	sedrule7="s/ (.*//"

	sedruleall="${sedrule1};${sedrule2};${sedrule3};${sedrule4};${sedrule5};${sedrule6};${sedrule7}"

	if [ -f "/sys/class/net/${1}/device/modalias" ]; then
		bus_type=$(cut -f 1 -d ":" < "/sys/class/net/${1}/device/modalias")

		if [ "${bus_type}" = "usb" ]; then
			vendor_and_device=$(cut -b 6-14 < "/sys/class/net/${1}/device/modalias" | sed 's/^.//;s/p/:/')
			if hash lsusb 2> /dev/null; then
				if [[ -n "${2}" ]] && [[ "${2}" = "read_only" ]]; then
					requested_chipset=$(lsusb | grep -i "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
				else
					chipset=$(lsusb | grep -i "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
				fi
			fi

		elif [[ "${bus_type}" =~ pci|ssb|bcma|pcmcia ]]; then
			if [[ -f /sys/class/net/${1}/device/vendor ]] && [[ -f /sys/class/net/${1}/device/device ]]; then
				vendor_and_device=$(cat "/sys/class/net/${1}/device/vendor"):$(cat "/sys/class/net/${1}/device/device")
				if [[ -n "${2}" ]] && [[ "${2}" = "read_only" ]]; then
					requested_chipset=$(lspci -d "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
				else
					chipset=$(lspci -d "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
				fi
			else
				if hash ethtool 2> /dev/null; then
					ethtool_output=$(ethtool -i "${1}" 2>&1)
					vendor_and_device=$(printf "%s" "${ethtool_output}" | grep "bus-info" | cut -f 3 -d ":" | sed 's/^ //')
					if [[ -n "${2}" ]] && [[ "${2}" = "read_only" ]]; then
						requested_chipset=$(lspci | grep "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
					else
						chipset=$(lspci | grep "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
					fi
				fi
			fi
		fi
	elif [[ -f /sys/class/net/${1}/device/idVendor ]] && [[ -f /sys/class/net/${1}/device/idProduct ]]; then
		vendor_and_device=$(cat "/sys/class/net/${1}/device/idVendor"):$(cat "/sys/class/net/${1}/device/idProduct")
		if hash lsusb 2> /dev/null; then
			if [[ -n "${2}" ]] && [[ "${2}" = "read_only" ]]; then
				requested_chipset=$(lsusb | grep -i "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
			else
				chipset=$(lsusb | grep -i "${vendor_and_device}" | head -n 1 | cut -f 3 -d ":" | sed -e "${sedruleall}")
			fi
		fi
	fi
}

#Override for managed_option function to set the interface on managed mode and manage the possible name change correctly
#shellcheck disable=SC2154
function realtek_chipset_fixer_override_managed_option() {

	debug_print

	if ! check_to_set_managed "${1}"; then
		return 1
	fi

	disable_rfkill

	language_strings "${language}" 17 "blue"
	ifconfig "${1}" up

	if [ "${1}" = "${interface}" ]; then
		if [ "${interface_airmon_compatible}" -eq 0 ]; then
			if ! set_mode_without_airmon "${1}" "managed"; then
				echo
				language_strings "${language}" 1 "red"
				language_strings "${language}" 115 "read"
				return 1
			else
				ifacemode="Managed"
			fi
		else
			set_chipset "${1}" "read_only"
			if [[ "${requested_chipset}" =~ ${realtek_chipset_regexp} ]]; then
				new_interface=$(${airmon} stop "${1}" 2> /dev/null | grep -E "${realtek_chipset_regexp}" | head -n 1)
			else
				new_interface=$(${airmon} stop "${1}" 2> /dev/null | grep station | head -n 1)
			fi

			ifacemode="Managed"
			[[ ${new_interface} =~ ^phy[0-9]{1,2}[[:blank:]]+([A-Za-z0-9]+)|\]?([A-Za-z0-9]+)\)?$ ]]
			if [ -n "${BASH_REMATCH[1]}" ]; then
				new_interface="${BASH_REMATCH[1]}"
			else
				new_interface="${BASH_REMATCH[2]}"
			fi

			if [ "${interface}" != "${new_interface}" ]; then
				if check_interface_coherence; then
					interface=${new_interface}
					phy_interface=$(physical_interface_finder "${interface}")
					check_interface_supported_bands "${phy_interface}" "main_wifi_interface"
					current_iface_on_messages="${interface}"
				fi
				echo
				language_strings "${language}" 15 "yellow"
			fi
		fi
	else
		if [ "${secondary_interface_airmon_compatible}" -eq 0 ]; then
			if ! set_mode_without_airmon "${1}" "managed"; then
				echo
				language_strings "${language}" 1 "red"
				language_strings "${language}" 115 "read"
				return 1
			fi
		else
			set_chipset "${1}" "read_only"
			if [[ "${requested_chipset}" =~ ${realtek_chipset_regexp} ]]; then
				new_secondary_interface=$(${airmon} stop "${1}" 2> /dev/null | grep -E "${realtek_chipset_regexp}" | head -n 1)
			else
				new_secondary_interface=$(${airmon} stop "${1}" 2> /dev/null | grep station | head -n 1)
			fi

			[[ ${new_secondary_interface} =~ ^phy[0-9]{1,2}[[:blank:]]+([A-Za-z0-9]+)|\]?([A-Za-z0-9]+)\)?$ ]]
			if [ -n "${BASH_REMATCH[1]}" ]; then
				new_secondary_interface="${BASH_REMATCH[1]}"
			else
				new_secondary_interface="${BASH_REMATCH[2]}"
			fi

			if [ "${1}" != "${new_secondary_interface}" ]; then
				secondary_wifi_interface=${new_secondary_interface}
				current_iface_on_messages="${secondary_wifi_interface}"
				echo
				language_strings "${language}" 15 "yellow"
			fi
		fi
	fi

	echo
	language_strings "${language}" 16 "yellow"
	language_strings "${language}" 115 "read"
	return 0
}

#Override for monitor_option function to set the interface on monitor mode and manage the possible name change correctly
#shellcheck disable=SC2154
function realtek_chipset_fixer_override_monitor_option() {

	debug_print

	if ! check_to_set_monitor "${1}"; then
		return 1
	fi

	disable_rfkill

	language_strings "${language}" 18 "blue"
	ifconfig "${1}" up

	if ! iwconfig "${1}" rate 1M > /dev/null 2>&1; then
		if ! set_mode_without_airmon "${1}" "monitor"; then
			echo
			language_strings "${language}" 20 "red"
			language_strings "${language}" 115 "read"
			return 1
		else
			if [ "${1}" = "${interface}" ]; then
				interface_airmon_compatible=0
				ifacemode="Monitor"
			else
				secondary_interface_airmon_compatible=0
			fi
		fi
	else
		if [ "${check_kill_needed}" -eq 1 ]; then
			language_strings "${language}" 19 "blue"
			${airmon} check kill > /dev/null 2>&1
			nm_processes_killed=1
		fi

		desired_interface_name=""
		if [ "${1}" = "${interface}" ]; then
			interface_airmon_compatible=1

			set_chipset "${1}" "read_only"
			if [[ "${requested_chipset}" =~ ${realtek_chipset_regexp} ]]; then
				new_interface=$(${airmon} start "${1}" 2> /dev/null | grep -E "${realtek_chipset_regexp}" | head -n 1)
			else
				new_interface=$(${airmon} start "${1}" 2> /dev/null | grep monitor)
			fi
			[[ ${new_interface} =~ ^You[[:space:]]already[[:space:]]have[[:space:]]a[[:space:]]([A-Za-z0-9]+)[[:space:]]device ]] && desired_interface_name="${BASH_REMATCH[1]}"
		else
			secondary_interface_airmon_compatible=1
			new_secondary_interface=$(${airmon} start "${1}" 2> /dev/null | grep monitor)
			[[ ${new_secondary_interface} =~ ^You[[:space:]]already[[:space:]]have[[:space:]]a[[:space:]]([A-Za-z0-9]+)[[:space:]]device ]] && desired_interface_name="${BASH_REMATCH[1]}"
		fi

		if [ -n "${desired_interface_name}" ]; then
			echo
			language_strings "${language}" 435 "red"
			language_strings "${language}" 115 "read"
			return 1
		fi

		if [ "${1}" = "${interface}" ]; then
			ifacemode="Monitor"
			[[ ${new_interface} =~ ^phy[0-9]{1,2}[[:blank:]]+([A-Za-z0-9]+)|\]?([A-Za-z0-9]+)\)?$ ]]
			if [ -n "${BASH_REMATCH[1]}" ]; then
				new_interface="${BASH_REMATCH[1]}"
			else
				new_interface="${BASH_REMATCH[2]}"
			fi

			if [ "${interface}" != "${new_interface}" ]; then
				if check_interface_coherence; then
					interface="${new_interface}"
					phy_interface=$(physical_interface_finder "${interface}")
					check_interface_supported_bands "${phy_interface}" "main_wifi_interface"
					current_iface_on_messages="${interface}"
				fi
				echo
				language_strings "${language}" 21 "yellow"
			fi
		else
			[[ ${new_secondary_interface} =~ ^phy[0-9]{1,2}[[:blank:]]+([A-Za-z0-9]+)|\]?([A-Za-z0-9]+)\)?$ ]]
			if [ -n "${BASH_REMATCH[1]}" ]; then
				new_secondary_interface="${BASH_REMATCH[1]}"
			else
				new_secondary_interface="${BASH_REMATCH[2]}"
			fi

			if [ "${1}" != "${new_secondary_interface}" ]; then
				secondary_wifi_interface="${new_secondary_interface}"
				current_iface_on_messages="${secondary_wifi_interface}"
				echo
				language_strings "${language}" 21 "yellow"
			fi
		fi
	fi

	echo
	language_strings "${language}" 22 "yellow"
	language_strings "${language}" 115 "read"
	return 0
}

#Override for prepare_et_interface function to assure the mode of the interface before the Evil Twin or Enterprise process
function realtek_chipset_fixer_override_prepare_et_interface() {

	debug_print

	et_initial_state=${ifacemode}

	if [ "${ifacemode}" != "Managed" ]; then
		if [ "${interface_airmon_compatible}" -eq 1 ]; then
			set_chipset "${interface}" "read_only"
			if [[ "${requested_chipset}" =~ ${realtek_chipset_regexp} ]]; then
				new_interface=$(${airmon} stop "${interface}" 2> /dev/null | grep -E "${realtek_chipset_regexp}" | head -n 1)
			else
				new_interface=$(${airmon} stop "${interface}" 2> /dev/null | grep station | head -n 1)
			fi

			ifacemode="Managed"
			[[ ${new_interface} =~ ^phy[0-9]{1,2}[[:blank:]]+([A-Za-z0-9]+)|\]?([A-Za-z0-9]+)\)?$ ]]
			if [ -n "${BASH_REMATCH[1]}" ]; then
				new_interface="${BASH_REMATCH[1]}"
			else
				new_interface="${BASH_REMATCH[2]}"
			fi

			if [ "${interface}" != "${new_interface}" ]; then
				if check_interface_coherence; then
					interface=${new_interface}
					phy_interface=$(physical_interface_finder "${interface}")
					check_interface_supported_bands "${phy_interface}" "main_wifi_interface"
					current_iface_on_messages="${interface}"
				fi
				echo
				language_strings "${language}" 15 "yellow"
			fi
		fi
	fi
}

#Override for restore_et_interface function to restore the state of the interfaces after Evil Twin or Enterprise process
#shellcheck disable=SC2154
function realtek_chipset_fixer_override_restore_et_interface() {

	debug_print

	echo
	language_strings "${language}" 299 "blue"

	disable_rfkill

	mac_spoofing_desired=0

	iw dev "${iface_monitor_et_deauth}" del > /dev/null 2>&1

	if [ "${et_initial_state}" = "Managed" ]; then
		set_mode_without_airmon "${interface}" "managed"
		ifacemode="Managed"
	else
		if [ "${interface_airmon_compatible}" -eq 1 ]; then
			set_chipset "${interface}" "read_only"
			if [[ "${requested_chipset}" =~ ${realtek_chipset_regexp} ]]; then
				new_interface=$(${airmon} start "${interface}" 2> /dev/null | grep -E "${realtek_chipset_regexp}" | head -n 1)
			else
				new_interface=$(${airmon} start "${interface}" 2> /dev/null | grep monitor)
			fi

			desired_interface_name=""
			[[ ${new_interface} =~ ^You[[:space:]]already[[:space:]]have[[:space:]]a[[:space:]]([A-Za-z0-9]+)[[:space:]]device ]] && desired_interface_name="${BASH_REMATCH[1]}"
			if [ -n "${desired_interface_name}" ]; then
				echo
				language_strings "${language}" 435 "red"
				language_strings "${language}" 115 "read"
				return
			fi

			ifacemode="Monitor"
			[[ ${new_interface} =~ ^phy[0-9]{1,2}[[:blank:]]+([A-Za-z0-9]+)|\]?([A-Za-z0-9]+)\)?$ ]]
			if [ -n "${BASH_REMATCH[1]}" ]; then
				new_interface="${BASH_REMATCH[1]}"
			else
				new_interface="${BASH_REMATCH[2]}"
			fi

			if [ "${interface}" != "${new_interface}" ]; then
				interface=${new_interface}
				phy_interface=$(physical_interface_finder "${interface}")
				check_interface_supported_bands "${phy_interface}" "main_wifi_interface"
				current_iface_on_messages="${interface}"
			fi
		else
			if set_mode_without_airmon "${interface}" "monitor"; then
				ifacemode="Monitor"
			fi
		fi
	fi
}

#Override for set_enterprise_control_script function to create here-doc bash script used for control windows on Enterprise attacks
#shellcheck disable=SC2154
function realtek_chipset_fixer_override_set_enterprise_control_script() {

	debug_print

	exec 7>"${tmpdir}${control_enterprise_file}"

	local control_msg
	if [ ${enterprise_mode} = "smooth" ]; then
		control_msg=${enterprise_texts[${language},3]}
	else
		control_msg=${enterprise_texts[${language},4]}
	fi

	set_chipset "${interface}" "read_only"

	cat >&7 <<-EOF
		#!/usr/bin/env bash
		interface="${interface}"
		et_initial_state="${et_initial_state}"
		interface_airmon_compatible=${interface_airmon_compatible}
		iface_monitor_et_deauth="${iface_monitor_et_deauth}"
		airmon="${airmon}"
		enterprise_returning_vars_file="${tmpdir}${enterprisedir}returning_vars.txt"
		enterprise_heredoc_mode="${enterprise_mode}"
		path_to_processes="${tmpdir}${enterprisedir}${enterprise_processesfile}"
		wpe_logfile="${tmpdir}${hostapd_wpe_log}"
		success_file="${tmpdir}${enterprisedir}${enterprise_successfile}"
		done_msg="${yellow_color}${enterprise_texts[${language},9]}${normal_color}"
		log_reminder_msg="${pink_color}${enterprise_texts[${language},10]}: [${normal_color}${enterprise_completepath}${pink_color}]${normal_color}"
		realtek_chipset_regexp="${realtek_chipset_regexp}"
		requested_chipset="${requested_chipset}"
	EOF

	cat >&7 <<-'EOF'
		#Restore interface to its original state
		function restore_interface() {

			if hash rfkill 2> /dev/null; then
				rfkill unblock all > /dev/null 2>&1
			fi

			iw dev "${iface_monitor_et_deauth}" del > /dev/null 2>&1

			if [ "${et_initial_state}" = "Managed" ]; then
				ifconfig "${interface}" down > /dev/null 2>&1
				iwconfig "${interface}" mode "managed" > /dev/null 2>&1
				ifconfig "${interface}" up > /dev/null 2>&1
				ifacemode="Managed"
			else
				if [ "${interface_airmon_compatible}" -eq 1 ]; then

					if [[ "${requested_chipset}" =~ ${realtek_chipset_regexp} ]]; then
						new_interface=$(${airmon} start "${1}" 2> /dev/null | grep -E "${realtek_chipset_regexp}" | head -n 1)
					else
						new_interface=$(${airmon} start "${interface}" 2> /dev/null | grep monitor)
					fi

					[[ ${new_interface} =~ ^phy[0-9]{1,2}[[:blank:]]+([A-Za-z0-9]+)|\]?([A-Za-z0-9]+)\)?$ ]]
					if [ -n "${BASH_REMATCH[1]}" ]; then
						new_interface="${BASH_REMATCH[1]}"
					else
						new_interface="${BASH_REMATCH[2]}"
					fi

					if [ "${interface}" != "${new_interface}" ]; then
						interface=${new_interface}
						phy_interface=$(basename "$(readlink "/sys/class/net/${interface}/phy80211")" 2> /dev/null)
						current_iface_on_messages="${interface}"
					fi
				else
					ifconfig "${interface}" down > /dev/null 2>&1
					iwconfig "${interface}" mode "monitor" > /dev/null 2>&1
					ifconfig "${interface}" up > /dev/null 2>&1
				fi
				ifacemode="Monitor"
			fi
		}

		#Save some vars to a file to get read from main script
		function save_returning_vars_to_file() {
			{
			echo -e "interface=${interface}"
			echo -e "phy_interface=${phy_interface}"
			echo -e "current_iface_on_messages=${current_iface_on_messages}"
			echo -e "ifacemode=${ifacemode}"
			} > "${enterprise_returning_vars_file}"
		}
	EOF

	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		cat >&7 <<-EOF
			function kill_tmux_windows() {

				local TMUX_WINDOWS_LIST=()
				local current_window_name
				readarray -t TMUX_WINDOWS_LIST < <(tmux list-windows -t "${session_name}:")
				for item in "\${TMUX_WINDOWS_LIST[@]}"; do
					[[ "\${item}" =~ ^[0-9]+:[[:blank:]](.+([^*-]))([[:blank:]]|\-|\*)[[:blank:]]?\([0-9].+ ]] && current_window_name="\${BASH_REMATCH[1]}"
					if [ "\${current_window_name}" = "${tmux_main_window}" ]; then
						continue
					fi
					if [ -n "\${1}" ]; then
						if [ "\${current_window_name}" = "\${1}" ]; then
							continue
						fi
					fi
					tmux kill-window -t "${session_name}:\${current_window_name}"
				done
			}
		EOF
	fi

	cat >&7 <<-'EOF'
		#Kill Evil Twin Enterprise processes
		function kill_enterprise_windows() {

			readarray -t ENTERPRISE_PROCESSES_TO_KILL < <(cat < "${path_to_processes}" 2> /dev/null)
			for item in "${ENTERPRISE_PROCESSES_TO_KILL[@]}"; do
				kill "${item}" &> /dev/null
			done
		}

		#Check if a hash or a password was captured (0=hash, 1=plaintextpass, 2=both)
		function check_captured() {

			local hash_captured=0
			local plaintext_password_captured=0
			readarray -t ENTERPRISE_LINES_TO_PARSE < <(cat < "${wpe_logfile}" 2> /dev/null)
			for item in "${ENTERPRISE_LINES_TO_PARSE[@]}"; do

				if [[ "${item}" =~ challenge: ]]; then
					hash_captured=1
				elif [[ "${item}" =~ password: ]]; then
					plaintext_password_captured=1
				fi
			done

			if [[ ${hash_captured} -eq 1 ]] || [[ ${plaintext_password_captured} -eq 1 ]]; then
				touch "${success_file}" > /dev/null 2>&1
			fi

			if [[ ${hash_captured} -eq 1 ]] && [[ ${plaintext_password_captured} -eq 0 ]]; then
				echo 0 > "${success_file}" 2> /dev/null
				return 0
			elif [[ ${hash_captured} -eq 0 ]] && [[ ${plaintext_password_captured} -eq 1 ]]; then
				echo 1 > "${success_file}" 2> /dev/null
				return 0
			elif [[ ${hash_captured} -eq 1 ]] && [[ ${plaintext_password_captured} -eq 1 ]]; then
				echo 2 > "${success_file}" 2> /dev/null
				return 0
			fi

			return 1
		}

		#Set captured hashes and passwords counters
		function set_captured_counters() {

			local new_username_found=0
			declare -A lines_and_usernames

			readarray -t CAPTURED_USERNAMES < <(grep -n -E "username:" "${wpe_logfile}" | sort -k 2,2 | uniq --skip-fields=1 2> /dev/null)
			for item in "${CAPTURED_USERNAMES[@]}"; do
				[[ ${item} =~ ([0-9]+):.*username:[[:blank:]]+(.*) ]] && line_number="${BASH_REMATCH[1]}" && username="${BASH_REMATCH[2]}"
				lines_and_usernames["${username}"]="${line_number}"
			done

			hashes_counter=0
			plaintext_pass_counter=0
			for item2 in "${lines_and_usernames[@]}"; do
				local line_to_check=$((item2 + 1))
				local text_to_check=$(sed "${line_to_check}q;d" "${wpe_logfile}" 2> /dev/null)
				if [[ "${text_to_check}" =~ challenge: ]]; then
					hashes_counter=$((hashes_counter + 1))
				elif [[ "${text_to_check}" =~ password: ]]; then
					plaintext_pass_counter=$((plaintext_pass_counter + 1))
				fi
			done
		}

		#Get last captured user name
		function get_last_username() {

			line_with_last_user=$(grep -E "username:" "${wpe_logfile}" | tail -1)
			[[ ${line_with_last_user} =~ username:[[:blank:]]+(.*) ]] && last_username="${BASH_REMATCH[1]}"
		}
	EOF

	cat >&7 <<-'EOF'

		date_counter=$(date +%s)
		last_username=""
		break_on_next_loop=0
		while true; do
			if [ ${break_on_next_loop} -eq 1 ]; then
				tput ed
			fi
	EOF

	cat >&7 <<-EOF
			if [ "${channel}" != "${et_channel}" ]; then
				et_control_window_channel="${et_channel} (5Ghz: ${channel})"
			else
				et_control_window_channel="${channel}"
			fi
			echo -e "\t${yellow_color}${enterprise_texts[${language},0]} ${white_color}// ${blue_color}BSSID: ${normal_color}${bssid} ${yellow_color}// ${blue_color}${enterprise_texts[${language},1]}: ${normal_color}\${et_control_window_channel} ${yellow_color}// ${blue_color}ESSID: ${normal_color}${essid}"
			echo
			echo -e "\t${green_color}${enterprise_texts[${language},2]}${normal_color}"
	EOF

	cat >&7 <<-'EOF'
			hours=$(date -u --date @$(($(date +%s) - date_counter)) +%H)
			mins=$(date -u --date @$(($(date +%s) - date_counter)) +%M)
			secs=$(date -u --date @$(($(date +%s) - date_counter)) +%S)
			echo -e "\t${hours}:${mins}:${secs}"

			if [ ${break_on_next_loop} -eq 0 ]; then
	EOF

	cat >&7 <<-EOF
				echo -e "\t${pink_color}${control_msg}${normal_color}\n"
			fi
	EOF

	cat >&7 <<-'EOF'
			echo
			if [ -z "${last_username}" ]; then
	EOF

	cat >&7 <<-EOF
				echo -e "\t${blue_color}${enterprise_texts[${language},6]}${normal_color}"
				echo -e "\t${blue_color}${enterprise_texts[${language},7]}${normal_color}: 0"
				echo -e "\t${blue_color}${enterprise_texts[${language},8]}${normal_color}: 0"
			else
				last_name_to_print="${blue_color}${enterprise_texts[${language},5]}:${normal_color}"
				hashes_counter_message="${blue_color}${enterprise_texts[${language},7]}:${normal_color}"
				plaintext_pass_counter_message="${blue_color}${enterprise_texts[${language},8]}:${normal_color}"
	EOF

	cat >&7 <<-'EOF'
				tput el && echo -e "\t${last_name_to_print} ${last_username}"
				echo -e "\t${hashes_counter_message} ${hashes_counter}"
				echo -e "\t${plaintext_pass_counter_message} ${plaintext_pass_counter}"
			fi

			if [ ${break_on_next_loop} -eq 1 ]; then
				kill_enterprise_windows
	EOF

	if [ "${AIRGEDDON_WINDOWS_HANDLING}" = "tmux" ]; then
		cat >&7 <<-EOF
				kill_tmux_windows "Control"
		EOF
	fi

	cat >&7 <<-'EOF'
				break
			fi

			if check_captured; then
				get_last_username
				set_captured_counters
			 	if [ "${enterprise_heredoc_mode}" = "smooth" ]; then
					break_on_next_loop=1
				fi
			fi

			echo -ne "\033[K\033[u"
			sleep 0.3
		done

		if [ "${enterprise_heredoc_mode}" = "smooth" ]; then
			echo
			echo -e "\t${log_reminder_msg}"
			echo
			echo -e "\t${done_msg}"

			if [ "${enterprise_heredoc_mode}" = "smooth" ]; then
				restore_interface
				save_returning_vars_to_file
			fi

			exit 0
		fi
	EOF

	exec 7>&-
	sleep 1
}
