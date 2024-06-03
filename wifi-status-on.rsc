# You can opt between two options:
# - Checking if interface and led are already up
# - Take the shortcut and do not check anything

# Checking interface and led status
# Reduce the amount of system log messages
:local interfaces [/interface wifi find where disabled=yes]
:foreach iface in=$interfaces do={
  /interface wifi enable $iface
  # /interface wifi set $iface disabled=no
}
:if ([/system leds get [find where leds="user-led"] type] = "off") do={
  /system leds set [find where leds="user-led"] type=on
}
:log info message="All wifi interfaces turned on"

# Without any status check
# /interface wifi enable [find]
# /system leds set [find where leds="user-led"] type=on
# :log info message="All wifi interfaces turned on"
