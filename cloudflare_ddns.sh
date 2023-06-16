#!/usr/bin/env bash
# Cloudflare DDNS script for Synology DSM
set -e

# Exit codes specific to this script.
EXIT_BAD_PARAMS=1
EXIT_BAD_FORMAT=2
EXIT_AUTH_FAILED=3
EXIT_NO_PREREQUISITES=4

# Proxy through Cloudflare? [true/false]
proxy="true"
cloudflare_api="https://api.cloudflare.com/client/v4"

###############################################################################
## Response mapping. We don't use all of them. But it's good to have them.   ##
## https://developers.cloudflare.com/api/ | /etc.defaults/ddns_provider.conf ##
###############################################################################
SUCCESS='good' # [The update was successful]
NO_CHANGES='nochg' # [The supplied IP address is already set for this host.]
HOSTNAME_DOES_NOT_EXIST='nohost' # [The hostname does not exist, or does not have Dynamic DNS enabled.]
HOSTNAME_BLOCKED='abuse' # [DDNS service for the hostname has been blocked for abuse.]
HOSTNAME_FORMAT_IS_INCORRECT='notfqdn' # [The format of hostname is not correct]
AUTHENTICATION_FAILED='badauth' # [Authentication failed]
DDNS_PROVIDER_DOWN='911' # [There is a problem or scheduled maintenance on provider side]
BAD_HTTP_REQUEST='badagent' # [DDNS function needs to be modified, please contact synology support]
HOSTNAME_FORMAT_INCORRECT='badparam' # [The format of hostname is not correct]
BAD_PARAMS='badparam' # [Missing or invalid parameters]
PROVIDER_ADDRESS_NOT_RESOLVED='badresolv' # [Failed to resolve provider address]
PROVIDER_TIMEOUT_CONNECTION='badconn' # [Failed to connect to provider server]

# Create or update the address.
function create_or_update_address() {
  # $1 is the username.
  # $2 is the password.
  # $3 is the hostname.
  # $4 is the ip address.
  # $5 is the record type (A or AAAA).
  local records; local method; local dns_request; local url; local dns_api; local req_headers

  dns_api="${cloudflare_api}/zones/${1}/dns_records"

  # shellcheck disable=SC2089
  req_headers="-H \"Authorization: Bearer ${2}\" -H \"Content-Type:application/json\""
  records=$(curl -s -X GET "${dns_api}?type=${5}&name=${3}" ${req_headers})

  # If the remote ip is the same as the one we have, then we don't need to do anything.
  if [[ "$(echo "${records}" | jq -r ".result[0].content")" == "${4}" ]]; then
    echo "${NO_CHANGES}"
    return
  fi

  # By default, update the DNS record. If it doesn't exist, create a new one.
  method="PUT"
  url="${dns_api}/$(echo "${records}" | jq -r ".result[0].id")"
  if [[ ${record_id} == "null" ]]; then
    method="POST"
    url="${dns_api}"
  fi

  dns_request=$(curl -s -X ${method} "${url}" ${req_headers} --data "{\"type\":\"${5}\",\"name\":\"${3}\",\"content\":\"${4}\",\"proxied\":${proxy}}")
  if [[ $(echo "${dns_request}" | jq -r ".success") != "true" ]]; then
    echo "${DDNS_PROVIDER_DOWN}"
    return
  fi
}

function main() {
  local username="${1}"
  local password="${2}"
  local hostname="${3}"
  local ipv4_address="${4}"
  local input; local ipv6_address; local update_ipv4; local update_ipv6
  
  command -v curl &> /dev/null || exit ${EXIT_NO_PREREQUISITES}
  command -v jq &> /dev/null || exit ${EXIT_NO_PREREQUISITES}
  command -v ddnsd &> /dev/null || exit ${EXIT_NO_PREREQUISITES}

  # Check if the credentials are valid.
  if [[ $(curl -s -X GET "${cloudflare_api}/user/tokens/verify" -H "Authorization: Bearer ${password}" -H "Content-Type:application/json" | jq -r ".success") != "true" ]]; then
    echo "${AUTHENTICATION_FAILED}"
    exit ${EXIT_AUTH_FAILED}
  fi

  input=$(/usr/syno/sbin/ddnsd -a)
  ipv4_address=$(echo "$input" | awk '/IPv4/ {print $2}')
  ipv6_address=$(echo "$input" | awk '/IPv6/ {print $2}')

  if [[ -z "${username}" || -z "${password}" || -z "${hostname}" ]]; then
    echo "${BAD_PARAMS}"
    exit $EXIT_BAD_PARAMS
  fi
  if [[ "${hostname}" != *.* ]]; then
    echo "${HOSTNAME_FORMAT_INCORRECT}"
    exit $EXIT_BAD_FORMAT
  fi

  update_ipv4=$(create_or_update_address "${username}" "${password}" "${hostname}" "${ipv4_address}" "A")
  # Only run the IPv6 update if we have an IPv6 address.
  if [[ "${ipv6_address}" != "" ]]; then
    update_ipv6=$(create_or_update_address "${username}" "${password}" "${hostname}" "${ipv6_address}" "AAAA")
  fi

  if [[ ${update_ipv4} == "${NO_CHANGES}" ]] || [[ ${update_ipv6} == "${NO_CHANGES}" ]]; then
    echo "${NO_CHANGES}"
    exit 0
  fi

  echo "${SUCCESS}"
  exit 0
}

main "$@"