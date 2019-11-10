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
