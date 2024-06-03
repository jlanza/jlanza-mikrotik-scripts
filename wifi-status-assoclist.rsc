# :local interfaces {"wifi24", "wifi50"}
:local interfaces [/interface wifi find where disabled=no]
:local ledOn [:len $interfaces]

:foreach iface in=$interfaces do={
  :local nameIface [/interface get $iface name]
  # Number of connected devices
  :local count [:len [/interface wifi registration-table find where interface=$nameIface]]
  # Don't like this one as it always print the count in console
  #:local count [/interface wifi registration-table print count-only where interface=$nameIface]

  # Disable interface
  :if ($count = 0) do={
    /interface wifi set $iface disabled=yes
    # /interface wifi disable $iface
    :local ssidIface [/interface wifi get [find name=$nameIface] configuration.ssid]
    :log info message="Wifi \"$ssidIface\" ($nameIface) turned off"  
    set $ledOn ($ledOn - 1)
  }
}

# Switch off led
:if ($ledOn = 0 and ([/system leds get [find where leds="user-led"] type] = "on")) do={
  /system leds set [find where leds="user-led"] type=off
}