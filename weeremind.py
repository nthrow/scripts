## requires weechat python plugin
# send periodic reminders to an IRC channel that you admin

import weechat

weechat.register("remind", "admin", "1.1", "MIT", "Send message periodically to a channel", "", "")

timer_hook = None
target_channel = ""
target_message = ""

def send_message(data, remaining_calls):
    global target_server, target_channel, target_message
    if target_server and target_channel and target_message:
        # Remove leading '#' if present for buffer_search
        buffer_name = "{}.{}".format(target_server, target_channel)
        channel_buffer = weechat.buffer_search("irc", buffer_name)
        if channel_buffer:
            weechat.command(channel_buffer, "/msg {} {}".format(target_channel, target_message))
        else:
            weechat.prnt("", "autosend: Buffer not found for '{}'".format(buffer_name))
    return weechat.WEECHAT_RC_OK

def autosend_cmd_cb(data, buffer, args):
    global timer_hook, target_server, target_channel, target_message
    argv = args.split()
    if not argv:
        weechat.prnt(buffer, "Usage: /autosend on <server> <#channel> <message> | /autosend off")
        return weechat.WEECHAT_RC_OK

    if argv[0] == "on":
        if len(argv) < 4:
            weechat.prnt(buffer, "Usage: /autosend on <server> <#channel> <message>")
            return weechat.WEECHAT_RC_OK
        target_server = argv[1]
        target_channel = argv[2]
        target_message = " ".join(argv[3:])
        if timer_hook is None:
            timer_hook = weechat.hook_timer(3600000, 0, 0, "send_message", "") # currently set to hourly
            weechat.prnt(buffer, "Autosend enabled: sending to {}.{}: {}".format(target_server, target_channel, target_message))
        else:
            weechat.prnt(buffer, "Autosend already running.")
    elif argv[0] == "off":
        if timer_hook is not None:
            weechat.unhook(timer_hook)
            timer_hook = None
            weechat.prnt(buffer, "Autosend disabled.")
        else:
            weechat.prnt(buffer, "Autosend is not running.")
    else:
        weechat.prnt(buffer, "Usage: /autosend on <server> <#channel> <message> | /autosend off")
    return weechat.WEECHAT_RC_OK

weechat.hook_command(
    "autosend",
    "Enable or disable autosend to a channel.",
    "on <channel> <message> | off",
    "on <channel> <message>: enable autosend to <channel> with <message>\n"
    "off: disable autosend",
    "on|off",
    "autosend_cmd_cb",
    ""
)
