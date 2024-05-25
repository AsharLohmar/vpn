#!/bin/bash
set -e


show_help () {
    cat << EOF
    Usage for$(basename "${0}") 
Global commands
  $(basename "${0}")  [ls|upgrade]
      ls        List active VPN
      upgrade   Upgrade all docker images and eliminate the dangling ones
  $(basename "${0}")  all stop
                Will stop all active VPN containers
                
VPN instance commands
  $(basename "${0}")  [-u] <vpn name> [start|stop|restart|shell|exec <command>|log]
      -u        Will call for pulling the latest version of the container
      start|stop|restart
                Will start, stop, or restart the VPN container
      shell     Connects to the shell inside the VPN's container
      exec <command>
                Excecutes the <command> inside the VPN's container
      log       Shows the output of the main process runnin in the container

VPN docker machine commands
  $(basename "${0}")  vm [start|stop|restart|shell|status]
      start|stop|restart
                Will start, stop, or restart the VPN container
      shell     Connects to the shell inside the VPN's container
      status    Shows the status of the vagrant machine hosting the docker machine
EOF
}

params="$(getopt -o ":hu" -- "$@")"
eval set -- "$params"
while [ "$#" -gt 0 ]; do
    case "$1" in
      -u) update="1"; shift ;;
      -h) show_help; exit ;;
      --) shift; break ;;
      *) ;;
   esac
done

VPN_BASE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
# shellcheck source=/dev/null
[ -f "${VPN_BASE}/.settings" ] && . "${VPN_BASE}/.settings"

name="${1:?vpn name}"
shift

# global commands
case "${name}" in
    ls) docker container ls -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"; exit ;;
    upgrade)
        docker images --format "{{.Repository}}" -f "reference=*/*latest" | xargs -n1 docker pull
        dangling="$(docker images -f "dangling=true" -q)"
        [ -n "${dangling}" ] && docker rmi "${dangling}"
        exit
        ;;
esac

op="${1:-start}"
shift || true

if [ "${name}" = "vm" ]; then
    case "${op}" in
        restart) cmd="reload" ;;
        start)   cmd="up" ;;
        stop)    cmd="halt" ;;
        shell)   cmd="ssh" ;;
        status)  cmd="status" ;;
        *)
            echo "Usage: $0 vm {start|stop|shell|status|reload|up|halt|ssh|ls}"
            exit 1
            ;;
    esac
    cd "${VPN_BASE}" && vagrant "${cmd}"
    exit
fi

VPN_HOME="${VPN_BASE}/conf/${name}"
VPN_MOUNT="${VPN_MOUNT:-$VPN_HOME}"

PROXY_PORT="${PROXY_PORT:-8443}"
PROXYPAC_PORT="${PROXYPAC_PORT:-8088}"
PROXY_BIND="${PROXY_BIND:-127.0.0.1}"
PROXY_ENDPOINT="${PROXY_ENDPOINT:-${PROXY_BIND}:${PROXY_PORT}}"

if [ "${name}" != "all" ] && [ ! -d "${VPN_HOME}" ]; then 
    echo "Unknown VPN ${name}"
    exit 1
fi


running="$(docker container ls -f "name=${name}" -q | wc -l)"
case "${op}" in 
    restart)  $0 "${name}" stop || true; $0 "${name}" start ;;
    start)
        if [ "${running}" -ne 0 ]; then
            echo "VPN ${name} already running"
            exit 2
        fi
        ensure_proxy=1
        d_args=( run --rm -it "--cap-add=NET_ADMIN" -v "${VPN_MOUNT}:/conf" --name "${name}" --hostname "${name}" --network vpn "$@" )
        [ "${update}" = "1" ] && d_args+=( "--pull=always" )
        # shellcheck source=/dev/null
        [ -f "${VPN_HOME}/.container_args" ] && . "${VPN_HOME}/.container_args" 
        
        if [ "${ensure_proxy}" = "1" ] && [ "$(docker container ls -f 'name=proxy' -q | wc -l)" = "0" ]; then
            echo "proxy not running run ${0} proxy"
        fi
        docker network inspect vpn >/dev/null 2>&1 || docker network create --driver bridge --subnet 192.168.253.0/24 --gateway 192.168.253.1  vpn
        docker "${d_args[@]}"
        ;;
    stop)
        if [ "${name}" = "all" ]; then
            docker container ls -a --format "table {{.Names}}\t{{.Image}}" | grep asharlohmar/glider | awk '{print $1}' | xargs docker stop -t1
        else
            if [ "${running}" = "0" ]; then
                echo "VPN ${name} is not running"
                exit 2
            else
                docker stop -t1 "${name}"
            fi
        fi
        ;;
    log)
        if [ "${running}" = "0" ]; then
            echo "VPN ${name} is not running"
            exit 2
        fi
        docker logs -f --since 10m "${name}"
        ;;
    shell)
        if [ "${running}" = "0" ]; then
            echo "VPN ${name} is not running"
            exit 2
        fi
        docker exec -it "${name}" /bin/sh -l
        ;;
    exec)
        docker exec -it "${name}" "${@}"
        ;;
    *)
        echo "Usage: ${0} {start|stop|log|shell|ls}"
        exit 1
        ;;
esac
