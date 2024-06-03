# References
# https://bayukurnia.com/blog/mikrotik-ddns-cloudflare-api/
# https://forum.mikrotik.com/viewtopic.php?t=205928#

# Work with only one root domain or subdomain.
# If you want to manage multiple domain or subdomain clone the script and change based on new domain
# Apply policies: read, write, ftp and test
# IMPORTANT: Before to start the script, remember to create manually the records for domain or subdomain.

# https://myip.wtf/text
# https://ip.wtf

# Script name to be included in logs, etc.
:local scriptName "cloudflare-ddns"

# Cloudflare token for edit the zone
:local cfToken ""

# Cloudflare ZoneID
:local cfZoneId ""

# Cloudflare domain name
:local domain ""
:local keepDnsRecordDetails true
:local dnsType "A"
:local dnsTTL 1
:local dnsProxied false

##### To obtain cfDnsId use following command in any unix shell:
##### curl -X GET "https://api.cloudflare.com/client/v4/zones/CF_ZONE_ID/dns_records" -H "Authorization: Bearer CF_API_TOKEN"
:local cfDnsId ""

# Set the name of interface where get the internet public IP
:local wanInterface "ether1"

:local externalDnsResolver false
:local dnsResolver "1.1.1.1"

# Use external DNS resolver or DNS records
# Not used in case Cloudflare DNS Record ID is not provided
:local useDnsRecords true

#------------------------------------------------------------------------------------
# DO NOT CHANGE ANYTHING BELOW
#------------------------------------------------------------------------------------

:local logPrefix "$scriptName ($domain)"

# Get current IP
:local currentIP 
# Check interface is running
:if ([/interface get $wanInterface value-name=running]) do={
  # Get IP address and strip netmask
  :set currentIP [/ip address get [find interface=$wanInterface] address];
  :set currentIP [:pick $currentIP 0 [:find $currentIP "/"]]
} else={
  :error [:log info "$logPrefix: $inetinterface is not currently running, so therefore will not update."]
}

:local previousIP
# Two options:
# 1) Resolve domain and update on IP changes. This method work only if use non proxied record.
# 2) Use Cloudflare API to retrieve IP address from DNS records and update on change

# Cloudflare API URL
:local cfApiDnsRecordURL "https://api.cloudflare.com/client/v4/zones/$cfZoneId/dns_records/$cfDnsId"
:local cfApiDnsRecordsListURL "https://api.cloudflare.com/client/v4/zones/$cfZoneId/dns_records?type=A&name=$domain"
:local authHeader "Authorization: Bearer $cfToken"

:if ([:len $cfDnsId] = 0) do={
  # Retrieve cfDnsId in case you were so lazy not to include it
  :log info "No DNS id provided. Overriding resolver configuration and accessing DNS Records to retrieve id and IP address"
  :do {
    :local httpResponse [/tool fetch mode=https http-method=get url="$cfApiDnsRecordsListURL" http-header-field="$authHeader" as-value output=user]
    :if ($httpResponse->"status" = "finished") do={
      :local jsonData [:deserialize from=json value=($httpResponse->"data")]
      :set cfDnsId ($jsonData->"result"->0->"id")
      :set previousIP ($jsonData->"result"->0->"content")
    }
  } on-error {
    :error [:log error "$logPrefix: Unable to access Cloudflare servers for retrieving information"]
  }
} else={
  # Resolve domain and update on IP changes. This method work only if use non proxied record.
  :if ($dnsProxied = false and $useDnsRecords = false) do={
    :if ($externalDnsResolver) do={
      :set previousIP [:resolve domain-name=$domain server=$dnsResolver]
    } else={
      :set previousIP [:resolve domain-name=$domain]
    }
  } else={
    :do {
      :local httpResponse [/tool fetch mode=https http-method=get url="$cfApiDnsRecordURL" http-header-field="$authHeader" as-value output=user]
      :if ($httpResponse->"status" = "finished") do={
        :set previousIP ([:deserialize from=json value=($httpResponse->"data")]->"result"->"content")
      }
    } on-error {
      :error [:log error "$logPrefix: Unable to access Cloudflare servers for retrieving information"]
    }
  }
}

:if ($currentIP != $previousIP) do={
  :log info "$logPrefix: Current IP ($currentIP) is not equal to previous IP ($previousIP), update needed"
  :local headers "Content-type:application/json,$authHeader"
  :local payload
  :if ($keepDnsRecordDetails) do={
    :set payload "{\"type\":\"$dnsType\",\"name\":\"$domain\",\"content\":\"$currentIP\"}"
  } else={
    :set payload "{\"type\":\"$dnsType\",\"name\":\"$domain\",\"content\":\"$currentIP\",\"ttl\":$dnsTTL,\"proxied\":$dnsProxied}"
  }
  :do {
    # Not able to use PATCH as not available in RouterOS
    :local httpResponse [/tool fetch mode=https http-method=put url="$cfApiDnsRecordURL" http-header-field="$headers" http-data="$payload" as-value output=user]
    :if ($httpResponse->"status" = "finished") do={
      :log info "$logPrefix: Updated on Cloudflare with IP $currentIP"
    }
  } on-error {
    :error [:log error "$logPrefix: Unable to access Cloudflare servers for updating information"]
  }
} else={
  :log info "$logPrefix: IP address ($previousIP) unchanged, no update needed"
}

