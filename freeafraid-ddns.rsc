
# Script name to be included in logs, etc.
:local scriptName "freeafraid-ddns"

# Domains to manage
# It can be either a simple array or a dictionary, provided the value includes the sync URL
:local domains {
  "test.domain-01.com"="https://sync.afraid.org/u/whatever01/";
  "test.domain-02.com"="https://sync.afraid.org/u/whatever01/";
}

# Set the name of interface where get the internet public IP
:local wanInterface "ether1"
:local externalIpLookup true

# DNS resolver configuration
:local externalDnsResolver false
:local dnsResolver "1.1.1.1"

# Check DNS before update or always send ddns update request and delegate
:local alwaysSendSyncRequest true

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

:foreach domain,url in=$domains do={  
  :local logPrefix "$scriptName ($domain)"
  
  :if ($alwaysSendSyncRequest) do={
    :do {
      :local httpResponse [/tool fetch mode=https http-method=get url="$url" as-value output=user]
      :if ($httpResponse->"status" = "finished") do={
        # :put [ :pick $w 0 ( [ :len $w ] -1 ) ];
        # :put [ :pick $line 0 [ :find $line "\n" ] ];
        # Remove \n included in response message
        :local msg [:pick ($httpResponse->"data") 0 ([:len ($httpResponse->"data")] - 1)]
        :log info ("$logPrefix: Success auto-sync. $msg")
      }
    } on-error {
      :error [:log error "$logPrefix: Unable to access FreeDNS Afraid servers for updating information"]
    }
  } else={
    :local previousIP
    :do {
      :if ($externalDnsResolver) do={
        :set previousIP [:resolve domain-name=$domain server=$dnsResolver]
      } else={
        :set previousIP [:resolve domain-name=$domain]
      }
    } on-error {
      :log warning "$logPrefix: Unable to locally resolve DNS name."
    }

    :if ($currentIP != $previousIP) do={
      :do {
        :local httpResponse [/tool fetch mode=https http-method=get url="$url" as-value output=user]
        :if ($httpResponse->"status" = "finished") do={
          # Remove \n included in response message
          :local msg [:pick ($httpResponse->"data") 0 ([:len ($httpResponse->"data")] - 1)]
          :log info ("$logPrefix: Success auto-sync. $msg")
        }
      } on-error {
        :error [:log error "$logPrefix: Unable to access FreeDNS Afraid servers for updating information"]
      }
    } else={
      :log info "$logPrefix: IP address ($previousIP) unchanged, no update needed"
    }
  }
}


