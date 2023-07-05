#!/usr/bin/env bash
################################################################################
#                                                                              #
#          Cloudflare DDNS Script for Synology DiskStation Manager             #
#                                                                              #
#  SYNOPSIS:                                                                   #
#  This script updates your Cloudflare DNS record with the IP address          #
#  of your Synology NAS. It creates or  updates the IPv4 and/or IPv6           #
#   address of the specified hostname.                                         #
#                                                                              #
#  USAGE:                                                                      #
#  ./cloudflare_ddns.sh <zone_id> <api_token> <hostname>                       #
#                                                                              #
#  PREREQUISITES:                                                              #
#  The 'curl', 'jq', and 'ddnsd' commands must be installed and available.     #
#                                                                              #
################################################################################


# Exit codes specific to this script.
EXIT_BAD_PARAMS=1
EXIT_BAD_FORMAT=2
EXIT_AUTH_FAILED=3
EXIT_NO_PREREQUISITES=4

# Check if we have the prerequisites. Exit early if we don't.
command -v curl &> /dev/null || exit ${EXIT_NO_PREREQUISITES}
command -v jq &> /dev/null || exit ${EXIT_NO_PREREQUISITES}
command -v ddnsd &> /dev/null || exit ${EXIT_NO_PREREQUISITES}

# Proxy through Cloudflare? [true/false]
proxy="true"

###############################################################################
## Response mapping. We don't use all of them. But it's good to have them.   ##
## https://developers.cloudflare.com/api/ | /etc.defaults/ddns_provider.conf ##
###############################################################################
SUCCESS='good' # [The update was successful.]
NO_CHANGES='nochg' # [The supplied IP address is already set for this host.]
HOSTNAME_DOES_NOT_EXIST='nohost' # [The hostname does not exist, or does not have Dynamic DNS enabled.]
HOSTNAME_BLOCKED='abuse' # [DDNS service for the hostname has been blocked for abuse.]
HOSTNAME_FORMAT_IS_INCORRECT='notfqdn' # [The format of hostname is not correct.]
AUTHENTICATION_FAILED='badauth' # [Authentication failed.]
DDNS_PROVIDER_DOWN='911' # [There is a problem or scheduled maintenance on provider side.]
BAD_HTTP_REQUEST='badagent' # [DDNS function needs to be modified, please contact synology support.]
HOSTNAME_FORMAT_INCORRECT='badparam' # [The format of hostname is not correct.]
BAD_PARAMS='badparam' # [Missing or invalid parameters.]
PROVIDER_ADDRESS_NOT_RESOLVED='badresolv' # [Failed to resolve provider address.]
PROVIDER_TIMEOUT_CONNECTION='badconn' # [Failed to connect to provider server.]

if [[ -z "${1}" || -z "${2}" || -z "${3}" ]]; then
  echo "${BAD_PARAMS}"
  exit ${EXIT_BAD_PARAMS}
fi

# Cloudflare API endpoints.
cloudflare_api="https://api.cloudflare.com/client/v4"
dns_api="${cloudflare_api}/zones/${1}/dns_records"
verify_token_api="${cloudflare_api}/user/tokens/verify"

function main() {
  # $1 is the zone id.
  # $2 is the token.
  # $3 is the hostname.
  # $4 is the ip address.
  local input; local ipv6_address; local update_ipv4; local update_ipv6;

  # Check if the credentials are valid.
  if [[ $(make_request "GET" ${verify_token_api} "${2}" | jq -r ".success") != "true" ]]; then
    echo "${AUTHENTICATION_FAILED}"
    exit ${EXIT_AUTH_FAILED}
  fi

  input=$(/usr/syno/sbin/ddnsd -a)
  # Uncomment to get the IPv4 address from ddnsd.
  #ipv4_address=$(echo "$input" | awk '/IPv4/ {print $2}')
  ipv6_address=$(echo "$input" | awk '/IPv6/ {print $2}')

  if [[ "${3}" != *.* ]]; then
    echo "${HOSTNAME_FORMAT_INCORRECT}"
    exit $EXIT_BAD_FORMAT
  fi

  update_ipv4=$(create_or_update_address "${1}" "${2}" "${3}" "${4}" "A")

  # Only run the IPv6 update if we have an IPv6 address.
  if [[ "${ipv6_address}" != "" ]]; then
    update_ipv6=$(create_or_update_address "${1}" "${2}" "${3}" "${ipv6_address}" "AAAA")
  fi

  if [[ ${update_ipv4} == "${NO_CHANGES}" ]] || [[ ${update_ipv6} == "${NO_CHANGES}" ]]; then
    echo "${NO_CHANGES}"
    exit 0
  fi

  echo "${SUCCESS}"
  exit 0
}

function make_request() {
  # $1 is the HTTP method (GET, POST, PUT, etc.)
  # $2 is the URL.
  # $3 is the token.
  # $4 is the data (optional).
  local response;

  if [[ "$1" == "GET" ]]; then
    response=$(curl -s -X "${1}" "${2}" -H "Authorization: Bearer ${3}" -H "Content-Type:application/json")
  else
    response=$(curl -s -X "${1}" "${2}" -H "Authorization: Bearer ${3}"  -H "Content-Type:application/json" --data "${4}")
  fi

  echo "${response}"
}

# Create or update the address.
function create_or_update_address() {
  # $1 is the zone id.
  # $2 is the token.
  # $3 is the hostname.
  # $4 is the ip address.
  # $5 is the record type (A or AAAA).
  local records; local method; local dns_request; local url; local record_id;

  records=$(make_request "GET" "${dns_api}?type=${5}&name=${3}" "${2}")

  # If the remote ip is the same as the one we have, then we don't need to do anything.
  if [[ "$(echo "${records}" | jq -r ".result[0].content")" == "${4}" ]]; then
    echo "${NO_CHANGES}"
    return
  fi

  # By default, update the DNS record. If it doesn't exist, create a new one.
  method="PUT"
  record_id=$(echo "${records}" | jq -r ".result[0].id")
  url="${dns_api}/${record_id}"
  if [[ ${record_id} == "null" ]]; then
    method="POST"
    url="${dns_api}"
  fi

  dns_request=$(make_request "${method}" "${url}" "${2}" "{\"type\":\"${5}\",\"name\":\"${3}\",\"content\":\"${4}\",\"proxied\":${proxy}}")

  if [[ $(echo "${dns_request}" | jq -r ".success") != "true" ]]; then
    echo "${DDNS_PROVIDER_DOWN}"
    return
  fi
}

main "$@"