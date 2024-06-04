# References
# https://bayukurnia.com/blog/mikrotik-ddns-cloudflare-api/
# https://forum.mikrotik.com/viewtopic.php?t=205928#

# Work with only multiple subdomains on the same zone.
# Apply policies: read, write, ftp and test
# IMPORTANT: Before to start the script, remember to create manually the records for domain or subdomain.

# https://myip.wtf/text
# https://ip.wtf

# Script name to be included in logs, etc.
:local scriptName "cloudflare-multi-ddns"

# Cloudflare token for edit the zone
:local cfToken ""

# Cloudflare ZoneID
:local cfZoneId ""

# Cloudflare domain names
# All domains must be of the same ZoneID
:local domains {
  "test-01.domain.com";
  "test-02.domain.com";
}

:local keepDnsRecordDetails true
:local dnsType "A"
:local dnsTTL 1
:local dnsProxied false

# Set the name of interface where get the internet public IP
:local wanInterface "ether1"
:local externalIpLookup true

#------------------------------------------------------------------------------------
# DO NOT CHANGE ANYTHING BELOW
#------------------------------------------------------------------------------------

# Get current IP
:local currentIP 
:if ($externalIpLookup) do={
  :do {
    :local httpResponse [/tool fetch mode=https http-method=get url="https://myip.wtf/text" as-value output=user]
    :if ($httpResponse->"status" = "finished") do={
      # Remove \n included in response message
      :set currentIP [:pick ($httpResponse->"data") 0 ([:len ($httpResponse->"data")] - 1)]
    }
  } on-error {
    :log warning "$scriptName: Unable to retrieve address from external service. Fallback to use locally retrieved."
  }
}

:if ([:len $currentIP] = 0) do={
  # Check interface is running
  :if ([/interface get $wanInterface value-name=running]) do={
    # Get IP address and strip netmask
    :set currentIP [/ip address get [find interface=$wanInterface] address];
    :set currentIP [:pick $currentIP 0 [:find $currentIP "/"]]
  } else={
    :error [:log error "$scriptName: $inetinterface is not currently running, so therefore will not update."]
  }
}

:local strDomains 
:foreach domain in=$domains do={
  set strDomains "$strDomains$domain,"
}

# Cloudflare API URL
:local cfApiDnsRecordsListURL "https://api.cloudflare.com/client/v4/zones/$cfZoneId/dns_records?type=A&name=$strDomains"
:local authHeader "Authorization: Bearer $cfToken"

:do {
  :local httpResponse [/tool fetch mode=https http-method=get url="$cfApiDnsRecordsListURL" http-header-field="$authHeader" as-value output=user]
  :if ($httpResponse->"status" = "finished") do={
    :local listDomains ([:deserialize from=json value=($httpResponse->"data")]->"result")

    :foreach domain in=$listDomains do={  
      :local name ($domain->"name")
      :local cfDnsId ($domain->"id")
      :local previousIP ($domain->"content")
      :local logPrefix "$scriptName ($name)"

      :if ($currentIP != $previousIP) do={
        :log info "$logPrefix: Current IP ($currentIP) is not equal to previous IP ($previousIP), update needed"
        :local cfApiDnsRecordURL "https://api.cloudflare.com/client/v4/zones/$cfZoneId/dns_records/$cfDnsId"
        :local headers "Content-type: application/json, $authHeader"
        :local payload
        :if ($keepDnsRecordDetails) do={
          :set payload "{\"type\":\"$dnsType\",\"name\":\"$name\",\"content\":\"$currentIP\"}"
        } else={
          :set payload "{\"type\":\"$dnsType\",\"name\":\"$name\",\"content\":\"$currentIP\",\"ttl\":$dnsTTL,\"proxied\":$dnsProxied}"
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
    }
  }
}
