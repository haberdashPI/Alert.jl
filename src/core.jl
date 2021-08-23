
"""

alert(message="Done!")

Display a cross-platform notification.

On MacOS, displays a notification window. On linux, tries to use notify-send,
zenity, kdialog or xmessage, in that order. On Windows or WSL2, uses a toast
notification.

Other platforms are not yet supported.

You can customize this function using [`set_alert_backend!`](@ref).

"""
alert(message="Done!") = alert_backend[](message)

"""

set_alert_backend!(fn)

Defines a custom backend for how `alert` sends messages to the user.
The argument should be a function of one argument (a string) which displays
the message to the user via some native UX api call.

If you wish to revert to the default backend, call this method with no arguments.

"""
set_alert_backend!(fn::Function) = alert_backend[] = fn
set_alert_backend!() = alert_backend[] = default_backend[]

const default_backend = Ref{Function}()
const alert_backend = Ref{Function}()

function init_alert_backends()
# select an appropriate implementation for sending alert notifications
default_backend[] = @static if Sys.isapple()
    message -> run(`osascript -e 'display notification "'$message'" with title "Julia"'`)
elseif Sys.islinux()
    if iswsl()
        win_toast
    elseif !isnothing(Sys.which("notify-send"))
        message -> run(`notify-send $message`)
    elseif !isnothing(Sys.which("zenity"))
        message -> run(pipeline(`echo $message`,`zenity --notification --listen`))
    elseif !isnothing(Sys.which("kdialog"))
        message -> run(`kdialog --title "Julia" --passivepopup $message 10`,wait=false)
    elseif !isnothing(Sys.which("xmessage"))
        message -> run(`xmessage $message`)
    else
        @warn("The `alert` method has no available local backend (call `alert()` for details).")
        message -> error("No viable messaging program available, install"*
        " 'notify-send', 'zenity', 'kdialog' or 'xmessage'.")
    end
elseif Sys.iswindows()
    win_toast
else
    @error "Unsupported operating system, no messages sent by `alert` will be "*
        "displayed. Consider using `AlertPushover`."
    message -> error("No alert backend installed! "*
        "Reload julia and read your error messages.")
end

alert_backend[] = default_backend[]
end

# Windows specific methods: `win_toast` and `iswsl`
# -----------------------------------------------------------------

@static if Sys.iswindows() || Sys.islinux()

# determine if the current system is Linux under WSL
function iswsl()
    try
        v = read("/proc/version", String)
        return occursin(r"microsoft",v)
    catch
        return false
    end
end

# display windows notification via powershell script
function win_toast(content)
    # format script input
    io = IOBuffer()
    show(io, content)
    disp_content = String(take!(io))

    # create a powershell script
    posh_script = """
    \$ErrorActionPreference = "Stop"

    \$notificationTitle = $disp_content

    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > \$null
    \$template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText01)

    #Convert to .NET type for XML manipuration
    \$toastXml = [xml] \$template.GetXml()
    \$toastXml.GetElementsByTagName("text").AppendChild(\$toastXml.CreateTextNode(\$notificationTitle)) > \$null

    #Convert back to WinRT type
    \$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    \$xml.LoadXml(\$toastXml.OuterXml)

    \$toast = [Windows.UI.Notifications.ToastNotification]::new(\$xml)
    \$toast.Tag = "PowerShell"
    \$toast.Group = "PowerShell"
    \$toast.ExpirationTime = [DateTimeOffset]::Now.AddMinutes(5)
    #\$toast.SuppressPopup = \$true

    \$notifier = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("PowerShell")
    \$notifier.Show(\$toast);
    """

    # encode as Base64 of Unicode-16
    io = IOBuffer()
    encode = Base64EncodePipe(io)
    write(encode, transcode(UInt16, posh_script))
    close(encode)
    str = String(take!(io))

    # send to powershell (works on windows and WSL2)
    run(`powershell.exe -Enc $str`)
end

end # if Sys.iswindows()
