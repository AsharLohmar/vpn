#!/bin/bash
set -e

name="${1:?vpn name}"
shift

VPN_BASE="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
# shellcheck source=/dev/null
[ -f "${VPN_BASE}/.settings" ] && . "${VPN_BASE}/.settings"


# global commands
case "${name}" in
    ls)
        docker container ls -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}"
        exit
        ;;
    upgrade)
        docker images --format "{{.Repository}}" -f "reference=*/*latest" | xargs -n1 docker pull
        dangling="$(docker images -f "dangling=true" -q)"
        [ -n "${dangling}" ] && docker rmi "${dangling}"
        exit
        ;;
esac

if [ $# -ge 1 ]; then
    op="${1}"
    shift
else
    op="start"
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
    restart)
        $0 "${name}" stop || echo ''
        $0 "${name}" start
        ;;
    start)
        if [ "${running}" != "0" ]; then
            echo "VPN ${name} already running"
            exit 2
        fi

        ensure_proxy=1
        d_args=( run --rm -it "--cap-add=NET_ADMIN" -v "${VPN_MOUNT}:/conf" --name "${name}" --network vpn "$@" )
        # shellcheck source=/dev/null
        [ -f "${VPN_HOME}/.container_args" ] && . "${VPN_HOME}/.container_args" 

        if [ "${ensure_proxy}" = "1" ] && [ "$(docker container ls -f 'name=proxy' -q | wc -l)" = "0" ]; then
            echo "proxy not running run ${0} proxy"
        fi

        docker network inspect vpn >/dev/null 2>&1 || docker network create --driver bridge --subnet 192.168.253.0/24 --gateway 192.168.253.1  vpn

        docker "${d_args[@]}"
        ;;
    stop)
        if [ "${name}" != "all" ] && [ "${running}" = "0" ]; then
            echo "VPN ${name} is not running"
            exit 2
        fi
        if [ "${name}" = "all" ]; then
            docker container ls -a --format "table {{.Names}}\t{{.Image}}" | grep asharlohmar/glider | awk '{print $1}' | xargs docker stop -t1
        else
            docker stop -t1 "${name}"
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

    *)
        echo "Usage: ${0} {start|stop|log|shell|ls}"
        exit 1
        ;;
esac
