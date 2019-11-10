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
