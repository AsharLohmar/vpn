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

_vpn_alias(){
    a="${COMP_WORDS[0]}"
    cc="${COMP_WORDS[1]}"
    mapfile -t COMP_WORDS < <(body="$(alias "$a")"; echo "${body#*=}"| xargs | tr ' ' '\n')
    COMP_WORDS+=( "${cc}")
    COMP_CWORD="2"
    _vpn
}


complete -F _vpn vpn

for i in $(alias | grep vpn | awk -F= '{print $1}'| awk '{print $2}'); do
    complete -F _vpn_alias "${i}"
done
