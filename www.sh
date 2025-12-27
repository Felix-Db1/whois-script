#!/usr/bin/env bash

# Define color codes (ANSI)
BLUE=$'\e[1;34m'
GREY=$'\e[0;39m'
RED=$'\e[38;5;160m'
CYAN=$'\e[38;5;51m'
YELLOW=$'\e[38;5;226m'
GOLD=$'\e[38;5;222m'
TANGERINE=$'\e[38;5;214m'
ORANGE=$'\e[38;5;202m'
RASPBERRY=$'\e[38;5;198m'
PINK=$'\e[38;5;205m'
LILAC=$'\e[38;5;183m'
VIOLET=$'\e[38;5;99m'
RESET=$'\e[0m'

# Define library path
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LIB_PATH="${LIB_PATH:-$SCRIPT_DIR/lib_www.sh}"

if [[ -f "$LIB_PATH" ]]; then
  . "$LIB_PATH"
else
  printf '%b\n' "${RED}Error:${RESET} library not found: ${LIB_PATH}" >&2
  exit 1
fi

# List of TLDs without WHOIS servers
NO_WHOIS_TLDS=(".al" ".bd" ".es" ".gr" ".hu" ".ng" ".np" ".pk" ".vn")

# List of TLDs requiring regular WHOIS handling
SPECIAL_TLDS=(".ae" ".africa" ".ar" ".az" ".bg" ".br" ".bw" ".ch" ".cl" ".de" ".dk" ".edu" ".eu" ".fi" ".fr" ".il" ".ke" ".lu" ".mk" ".mx" ".nl" ".pe" ".pl" ".pt" ".sa" ".si" ".tr" ".tw" ".tz" ".ug" ".za")

# Check for help flag
if [[ "$1" == "-h" ]]; then
    printf '%b\n' "${CYAN}Usage:${RESET}"
    printf '%b\n' "  www [-h]"
    printf '%b\n' "  www [domain]\n"

    printf '%b\n' "${CYAN}Description:${RESET}"
    printf '%b\n' "  Analyzes a given domain by removing prefixes such as 'http://', 'https://', and 'www.',"
    printf '%b\n' "  as well as any trailing slash ('/'). It then performs a WHOIS lookup to display key"
    printf '%b\n' "  information and executes DNS lookups for A, MX, and TXT records.\n"

    printf '%b\n' "${CYAN}Options:${RESET}"
    printf '%b\n' "  -h      show this help menu"
    printf '%b\n' "  domain  the domain to be analyzed (e.g., https://www.example.com/)"
    exit 0
fi

# Validate input
domain="$1"
if [[ -z "$domain" ]]; then
    printf '%b\n' "${TANGERINE}Warning:${RESET} Provide '-h' for help or specify a domain as an argument." >&2
    exit 1
fi

domain="${domain#https://}"
domain="${domain#http://}"
domain="${domain#www.}"
domain="${domain%/}"
domain="$(printf '%s' "$domain" | tr '[:upper:]' '[:lower:]')"

if [[ ! "$domain" =~ ^[[:alnum:]]+(-?[[:alnum:]]+)*(\.[[:alnum:]]+)+$ ]]; then
    printf '%b\n' "${RED}Error:${RESET} Invalid domain format: ${domain}" >&2
    exit 1
fi

# Check for TLD without WHOIS server
is_no_whois_tld=false
for tld in "${NO_WHOIS_TLDS[@]}"; do
    if [[ "$domain" == *"$tld" ]]; then
        is_no_whois_tld=true
        break
    fi
done

# Check for special TLD
is_special_tld=false
for tld in "${SPECIAL_TLDS[@]}"; do
    if [[ "$domain" == *"$tld" ]]; then
        is_special_tld=true
        break
    fi
done

# Execute lookups based on domain TLD
if [[ "$is_no_whois_tld" == true ]]; then
    perform_whois_unavailable "$domain"
elif [[ "$is_special_tld" == true ]]; then
    perform_whois_special "$domain"
elif [[ "$domain" =~ \.au$ ]]; then
    perform_whois_au "$domain"
elif [[ "$domain" =~ \.uk$ ]]; then
    perform_whois_uk "$domain"
else
    perform_whois "$domain"
fi

dig_records "$domain"