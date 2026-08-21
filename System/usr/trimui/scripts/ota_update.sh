#!/bin/sh
. /mnt/SDCARD/System/usr/trimui/scripts/update_common.sh

run_bootstrap() {
	curl -k -s https://raw.githubusercontent.com/$GITHUB_REPOSITORY/main/_assets/scripts/ota_bootstrap.sh | sh
}

main() {
	check_connection
	sleep 2
	clear
	run_bootstrap
	clear

	echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n" >>"$updatedir/ota_release.log"
	echo -e "${timestamp}\n" >>"$updatedir/ota_release.log"
	/mnt/SDCARD/System/usr/trimui/scripts/update_ota_release.sh | tee -a "$updatedir/ota_release.log"

	# if there is no release to apply, we check if there is hotfix for this version
	if grep -q -E "^(no release|user cancel)$" "/tmp/ota_release_result"; then # "no release", "user cancel", "download failed", "success"
		url="https://raw.githubusercontent.com/$GITHUB_REPOSITORY/main/_assets/hotfixes/JukaMix_$Local_JukaMixVersion.sh"

		if /mnt/SDCARD/System/bin/wget -q --spider "$url"; then

			echo -e "\n~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~\n\n" >>"$updatedir/ota_hotfix.log"
			echo -e "${timestamp}\n" >>"$updatedir/ota_hotfix.log"
			curl -k -s "$url" | sh | tee -a "$updatedir/ota_hotfix.log"

		else
			clear
			echo -ne "${PURPLE}Retrieving hotfix information.. ${NC}"
			echo -ne "${GREEN}DONE${NC}\n\n\n"
			echo -e "No hotfix available for JukaMix v$Local_JukaMixVersion.\n"
			echo -ne "${YELLOW}"
			echo "Press any button to exit..."
			# Wait for any button press (controller-compatible)
			timeout 5 /mnt/SDCARD/System/usr/trimui/scripts/evtest /dev/input/event0 2>/dev/null | head -1 > /dev/null 2>&1
		fi
	fi
	sleep 2
	killall -2 SimpleTerminal

}

main
