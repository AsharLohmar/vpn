_vpn() {
	VPN_BASE="$(dirname "$(realpath "$(which vpn)")")"
	if [ "${COMP_CWORD}" == "1" ]; then
		mapfile -t COMPREPLY < <(compgen -W "ls upgrade vm $(find "${VPN_BASE}"/conf -maxdepth 1 -mindepth 1 -type d -print0 |xargs -0 -n1 basename | sort)" "${COMP_WORDS[1]}")
	elif [ "${COMP_CWORD}" == "2" ]; then
		vpn_name="${COMP_WORDS[1]}"
		case "$vpn_name" in
			ls|upgrade)
			return 0
			;;
			*)
				options="start stop restart shell"
				if [ "${COMP_WORDS[1]}" == "vm" ]; then
					options="${options} status"
				else
					options="${options} log"
				fi
				mapfile -t COMPREPLY < <(compgen -W "${options}" "${COMP_WORDS[2]}")
			;;
		esac
	fi	
}
complete -F _vpn vpn
