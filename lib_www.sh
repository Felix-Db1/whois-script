#!/usr/bin/env bash

# Display a lookup URL for domains with no public WHOIS server
perform_whois_unavailable() {
    local domain="$1"
    local tld=".${domain##*.}"

    printf "%b> WHOIS server is not available for: %s%b\n" "$BLUE" "$tld" "$GREY"

    printf "%b\nLookup URL:%b\n" "$CYAN" "$GREY"
    case "$tld" in
        .al)
            echo "https://www.eurodns.com/whois-search/al-domain-name"
            ;;
        .bd)
            echo "https://www.eurodns.com/whois-search/com.bd-domain-name"
            ;;
        .es)
            echo "https://nic.es/sgnd/dominio/publicBuscarDominios.action"
            ;;
        .gr)
            echo "https://grweb.ics.forth.gr/public/whois?lang=en"
            ;;
        .hu)
            echo "https://info.domain.hu/webwhois/hu"
            ;;
        .ng)
            echo "https://whois.net.ng"
            ;;
        .np)
            echo "https://register.com.np/whois-lookup"
            ;;
        .pk)
            echo "https://pknic.net.pk"
            ;;
        .vn)
            echo "https://vnnic.vn/en/whois-information?lang=en"
            ;;
    esac
}

# Perform a regular WHOIS lookup for special TLDs
perform_whois_special() {
    local domain="$1"

    printf "%b> Performing regular WHOIS lookup for: %s%b\n" "$BLUE" "$domain" "$GREY"
    if ! whois_output=$(whois "$domain" 2>/dev/null); then
        printf "%b\n[Failed to retrieve WHOIS information]%b\n" "$RED" "$GREY"
        return 1
    fi

    if server=$(echo "$whois_output" | grep -i '^whois server:' | awk '{print $3}'); then
        if [[ -n "$server" ]]; then
            whois_output=$(whois -h "$server" "$domain" 2>/dev/null)
        fi
    fi

    printf "%b\nWHOIS Output:%b\n" "$CYAN" "$GREY"
    echo "$whois_output"
}

# Perform a WHOIS lookup for .au and display key information
perform_whois_au() {
    local domain="$1"

    printf "%b> Performing AU-specific WHOIS lookup for: %s%b\n" "$BLUE" "$domain" "$GREY"
    if ! whois_output=$(whois "$domain" 2>/dev/null); then
        printf "%b\n[Failed to retrieve WHOIS information]%b\n" "$RED" "$GREY"
        return 1
    fi

    REGISTRAR_DATA=$(echo "$whois_output" |
        grep -E '^[[:space:]]*(Registrar WHOIS Server|Registrar URL|Registrar Name|Reseller Name|Reseller):' |
        sed -E '
            s/^[[:space:]]*Registrar WHOIS Server:[[:space:]]*(.*)/WHOIS Server: \1/;
            s/^[[:space:]]*Registrar URL:[[:space:]]*(.*)/URL:          \1/;
            s/^[[:space:]]*Registrar Name:[[:space:]]*(.*)/Registrar:    \1/;
            s/^[[:space:]]*Reseller Name:[[:space:]]*(.*)/Reseller:     \1/;
            s/^[[:space:]]*Reseller:[[:space:]]*(.*)/Reseller:     \1/
        ' | awk 'NF && !/^Reseller:[[:space:]]*$/ { print }' | sort -u)

    SORTED_REGISTRAR=$(echo "$REGISTRAR_DATA" | awk '
        /^Registrar:/ { registrar = $0 }
        /^URL:/ { url = $0 }
        /^WHOIS Server:/ { whois_server = $0 }
        /^Reseller:/ { reseller = $0 }
        END {
            if (registrar) print registrar
            if (url) print url
            if (whois_server) print whois_server
            if (reseller) print reseller
        }')

    if [[ -z "$SORTED_REGISTRAR" ]]; then
        printf "%b\nRegistrar Information:%b\n%b[Could not parse WHOIS data]%b\n" "$YELLOW" "$GREY" "$RED" "$GREY"
    else
        printf "%b\nRegistrar Information:%b\n%s\n" "$YELLOW" "$GREY" "$SORTED_REGISTRAR"
    fi

    REGISTRANT_ID=$(echo "$whois_output" |
        grep -E '^(Registrant|Eligibility) ID:' |
        sed -E '
            s/^(Registrant|Eligibility) ID:[[:space:]]*ABN[[:space:]]*([0-9]+)/ABN: \2/;
            s/^(Registrant|Eligibility) ID:[[:space:]]*ACN[[:space:]]*([0-9]+)/ACN: \2/' |
        sort -u
    )

    if [[ -z "$REGISTRANT_ID" ]]; then
        printf "%b\nRegistrant ID:%b\n%b[Could not parse WHOIS data]%b\n" "$VIOLET" "$GREY" "$RED" "$GREY"
    else
        printf "%b\nRegistrant ID:%b\n%s\n" "$VIOLET" "$GREY" "$REGISTRANT_ID"
    fi

    IMPORTANT_DATES=$(echo "$whois_output" | grep -E '^Last Modified:' | sed -E '
        s/^Last Modified:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/Last Modified: \1/
    ')

    if [[ -z "$IMPORTANT_DATES" ]]; then
        printf "%b\nImportant Dates:%b\n%b[Could not parse WHOIS data]%b\n" "$GOLD" "$GREY" "$RED" "$GREY"
    else
        printf "%b\nImportant Dates:%b\n%s\n" "$GOLD" "$GREY" "$IMPORTANT_DATES"
    fi

    DOMAIN_STATUS=$(echo "$whois_output" |
        grep -E '^[S]tatus:' |
        sed -E 's/^Status:[[:space:]]*//' |
        awk 'NF {print $1}' |
        sort -u)

    if [[ -z "$DOMAIN_STATUS" ]]; then
        printf "%b\nDomain Status:%b\n%b[Could not parse WHOIS data]%b\n" "$TANGERINE" "$GREY" "$RED" "$GREY"
    else
        printf "%b\nDomain Status:%b\n%s\n" "$TANGERINE" "$GREY" "$DOMAIN_STATUS"
    fi

    NAME_SERVERS=$(echo "$whois_output" |
        grep -i '^[[:space:]]*Name Server:' |
        grep -iv '^[[:space:]]*Name Server IP:' |
        sed -E 's/^[[:space:]]*Name Server:[[:space:]]*//' |
        sed -E 's/^[[:space:]]+|[[:space:]]+$//' |
        awk '{print tolower($0)}' |
        sort -u)

    if [[ -z "$NAME_SERVERS" ]]; then
        printf "%b\nNameservers:%b\n%b[Could not parse WHOIS data]%b\n" "$ORANGE" "$GREY" "$RED" "$GREY"
    else
        printf "%b\nNameservers:%b\n" "$ORANGE" "$GREY"
        while read -r ns; do
            ip=$(ping -c 1 -W 1 "$ns" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
            if [[ -n "$ip" ]]; then
                printf "%s (%s)\n" "$ns" "$ip"
            else
                printf "%s\n" "$ns"
            fi
        done <<< "$NAME_SERVERS"
    fi
}

# Perform a WHOIS lookup for .uk and display key information
perform_whois_uk() {
    local domain="$1"

    printf "%b> Performing UK-specific WHOIS lookup for: %s%b\n" "$BLUE" "$domain" "$GREY"
    if ! whois_output=$(whois "$domain" 2>/dev/null); then
        printf "%b\n[Failed to retrieve WHOIS information]%b\n" "$RED" "$GREY"
        return 1
    fi

    WHOIS_BLOCK=$(echo "$whois_output" |
        sed -n '/^[[:space:]]*Registrar:/,/^[[:space:]]*WHOIS/p' |
        sed 's/^[[:space:]]*//' |
        sed '$d')

    if [[ -z "$WHOIS_BLOCK" ]]; then
        printf "%b\n[Could not parse WHOIS data]%b\n" "$RED" "$GREY"
    else
        local inside_nameservers=0
        local nameservers=()

        while read -r line; do
            if [[ "$line" == Name\ servers:* ]]; then
                printf "%b%s%b\n" "$ORANGE" "$line" "$GREY"
                inside_nameservers=1
                continue
            fi

            if (( inside_nameservers )); then
                if [[ -z "$line" || "$line" =~ ^[A-Z] ]]; then
                    inside_nameservers=0
                else
                    trimmed=$(echo "$line" | sed -E 's/^[[:space:]]+|[[:space:]]+$//' | tr '[:upper:]' '[:lower:]')
                    nameservers+=("$trimmed")
                    continue
                fi
            fi

            case "$line" in
                Registrar:*)
                    printf "%b\n%s%b\n" "$YELLOW" "$line" "$GREY"
                    ;;
                Relevant\ dates:*)
                    printf "%b%s%b\n" "$GOLD" "$line" "$GREY"
                    ;;
                Registration\ status:*)
                    printf "%b%s%b\n" "$TANGERINE" "$line" "$GREY"
                    ;;
                *)
                    printf "%s\n" "$line"
                    ;;
            esac
        done <<< "$WHOIS_BLOCK"

        for ns in "${nameservers[@]}"; do
            ip=$(ping -c 1 -W 1 "$ns" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
            if [[ -n "$ip" ]]; then
                printf "%s (%s)\n" "$ns" "$ip"
            else
                printf "%s\n" "$ns"
            fi
        done
    fi
}

# Perform a WHOIS lookup and display key information
perform_whois() {
    local domain="$1"

    printf "%b> Performing WHOIS lookup for: %s%b\n" "$BLUE" "$domain" "$GREY"
    if ! whois_output=$(whois "$domain" 2>/dev/null); then
        printf "%b\n[Failed to retrieve WHOIS information]%b\n" "$RED" "$GREY"
        return 1
    fi

    REGISTRAR_DATA=$(echo "$whois_output" | grep -E '^[[:space:]]*(Registrar WHOIS Server|Registrar URL|Registrar|Reseller Name|Reseller):' | sed -E '
        s/^[[:space:]]*Registrar WHOIS Server:[[:space:]]*(.*)/WHOIS Server: \1/;
        s/^[[:space:]]*Registrar URL:[[:space:]]*(.*)/URL:          \1/;
        s/^[[:space:]]*Registrar:[[:space:]]*(.*)/Registrar:    \1/;
        s/^[[:space:]]*Reseller Name:[[:space:]]*(.*)/Reseller:     \1/;
        s/^[[:space:]]*Reseller:[[:space:]]*(.*)/Reseller:     \1/
    ' | awk 'NF && !/^Reseller:[[:space:]]*$/ { print }' | sort -u)

    SORTED_REGISTRAR=$(echo "$REGISTRAR_DATA" | awk '
        /^Registrar:/ { registrar = $0 }
        /^URL:/ { url = $0 }
        /^WHOIS Server:/ { whois_server = $0 }
        /^Reseller:/ { reseller = $0 }
        END {
            if (registrar) print registrar
            if (url) print url
            if (whois_server) print whois_server
            if (reseller) print reseller
        }')

    if [[ -z "$SORTED_REGISTRAR" ]]; then
        printf "%b\nRegistrar Information:%b\n%b[Could not parse WHOIS data]%b\n" "$YELLOW" "$GREY" "$RED" "$GREY"
    else
        printf "%b\nRegistrar Information:%b\n%s\n" "$YELLOW" "$GREY" "$SORTED_REGISTRAR"
    fi

    DATES_BASE=$(echo "$whois_output" | grep -E '^[[:space:]]*(Updated Date|Creation Date):' | sed -E '
        s/^[[:space:]]*Updated Date:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/Updated:    \1/;
        s/^[[:space:]]*Creation Date:[[:space:]]*([0-9]{4}-[0-9]{2}-[0-9]{2}).*/Creation:   \1/
    ')

    EXP_DATE=$(
        echo "$whois_output" | awk '
            function pick_date(line) {
                if (match(line, /[0-9]{4}-[0-9]{2}-[0-9]{2}/)) return substr(line, RSTART, RLENGTH)
                return ""
            }

            /^[[:space:]]*Registrar Registration Expiration Date[[:space:]]*:/ {
                d = pick_date($0)
                if (d != "") { print d; exit }
            }

            /^[[:space:]]*Registry Expiry Date[[:space:]]*:/ {
                d = pick_date($0)
                if (d != "") reg = d
            }

            END {
                if (reg != "") print reg
            }
        '
    )

    IMPORTANT_DATES="$DATES_BASE"
    if [[ -n "$EXP_DATE" ]]; then
        IMPORTANT_DATES="${IMPORTANT_DATES}"$'\n'"Expiration: ${EXP_DATE}"
    fi

    IMPORTANT_DATES=$(printf '%s\n' "$IMPORTANT_DATES" | awk 'NF' | sort -u)

    SORTED_DATES=$(echo "$IMPORTANT_DATES" | awk '
        /^Creation:/ { creation = $0 }
        /^Updated:/ { updated = $0 }
        /^Expiration:/ { expiration = $0 }
        END {
            if (creation) print creation
            if (updated) print updated
            if (expiration) print expiration
        }')

    if [[ -z "$SORTED_DATES" ]]; then
        printf "%b\nImportant Dates:%b\n%b[Could not parse WHOIS data]%b\n" "$GOLD" "$GREY" "$RED" "$GREY"
    else
        printf "%b\nImportant Dates:%b\n%s\n" "$GOLD" "$GREY" "$SORTED_DATES"
    fi

    DOMAIN_STATUS=$(echo "$whois_output" |
        grep -i '\bDomain Status\b' |
        sed -E 's/^[[:space:]]*Domain Status:[[:space:]]*//' |
        awk 'NF {print $1}' |
        sort -u)

    if [[ -z "$DOMAIN_STATUS" ]]; then
        printf "%b\nDomain Status:%b\n%b[Could not parse WHOIS data]%b\n" "$TANGERINE" "$GREY" "$RED" "$GREY"
    else
        printf "%b\nDomain Status:%b\n%s\n" "$TANGERINE" "$GREY" "$DOMAIN_STATUS"
    fi

    NAME_SERVERS=$(echo "$whois_output" |
        grep -i '^[[:space:]]*Name Server:' |
        grep -iv '^[[:space:]]*Name Server IP:' |
        sed -E 's/^[[:space:]]*Name Server:[[:space:]]*//' |
        sed -E 's/^[[:space:]]+|[[:space:]]+$//' |
        awk '{print tolower($0)}' |
        sort -u)

    if [[ -z "$NAME_SERVERS" ]]; then
        printf "%b\nNameservers:%b\n%b[Could not parse WHOIS data]%b\n" "$ORANGE" "$GREY" "$RED" "$GREY"
    else
        printf "%b\nNameservers:%b\n" "$ORANGE" "$GREY"
        while read -r ns; do
            ip=$(ping -c 1 -W 1 "$ns" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
            if [[ -n "$ip" ]]; then
                printf "%s (%s)\n" "$ns" "$ip"
            else
                printf "%s\n" "$ns"
            fi
        done <<< "$NAME_SERVERS"
    fi
}

# Perform DNS lookups for A, MX, and TXT records
dig_records() {
    local domain="$1"

    printf "%b\n> Fetching DNS records for: %s%b\n" "$BLUE" "$domain" "$GREY"

    A_RECORDS=$(dig +short "$domain" | sort -n)
    if [[ -z "$A_RECORDS" ]]; then
        printf "%b\n1) A Record(s):%b\n%b[No A records found]%b\n" "$RASPBERRY" "$GREY" "$RED" "$GREY"
    else
        printf "%b\n1) A Record(s):%b\n" "$RASPBERRY" "$GREY"
        while read -r ip; do
            reverse_lookup=$(host "$ip" | awk '/pointer/ {print $5}' | sed 's/\.$//')
            if [[ -n "$reverse_lookup" ]]; then
                printf "%s (%s)\n" "$ip" "$reverse_lookup"
            else
                printf "%s\n" "$ip"
            fi
        done <<< "$A_RECORDS"
    fi

    MX_RECORDS=$(dig +short mx "$domain" | sort -n)
    if [[ -z "$MX_RECORDS" ]]; then
        printf "%b\n2) MX Record(s):%b\n%b[No MX records found]%b\n" "$PINK" "$GREY" "$RED" "$GREY"
    else
        printf "%b\n2) MX Record(s):%b\n" "$PINK" "$GREY"
        while read -r mx; do
            priority=$(echo "$mx" | awk '{print $1}')
            mx_host=$(echo "$mx" | awk '{print $2}')
            mx_host="${mx_host%.}"
            
            ip=$(ping -c 1 -W 1 "$mx_host" 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | head -n 1)
            if [[ -n "$ip" ]]; then
                printf "%s %s (%s)\n" "$priority" "$mx_host" "$ip"
            else
                printf "%s %s\n" "$priority" "$mx_host"
            fi
        done <<< "$MX_RECORDS"
    fi

    TXT_RECORDS=$(dig +short txt "$domain" | sort -n)
    if [[ -z "$TXT_RECORDS" ]]; then
        printf "%b\n3) TXT Record(s):%b\n%b[No TXT records found]%b\n" "$LILAC" "$GREY" "$RED" "$GREY"
    else
        printf "%b\n3) TXT Record(s):%b\n%s\n" "$LILAC" "$GREY" "$TXT_RECORDS"
    fi
}