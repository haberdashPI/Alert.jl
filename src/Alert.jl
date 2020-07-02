module Alert
using Base64
using Dates

export alert, @alert

"""
    @alert [duration] [message] begin
        [body]
    end

Calls [`alert`](@ref) if `body` takes longer than
`duration` (default to 2.0) seconds to complete.
"""
macro alert(args...)
    if length(args) == 0
        error("Missing body for @alert macro.")
    end
    options = args[1:end-1]
    body = args[end]

    return quote
        start_time = Dates.now()
        $(esc(body))
        delay, msg = Alert.__at_alert_options__($options...)
        if (Dates.now() - start_time) > Dates.Millisecond(round(Int,1000delay))
            alert(msg)
        end
    end
end

__at_alert_options__() = 2.0, "Done!"
__at_alert_options__(str::AbstractString) = 2.0, str
__at_alert_options__(num::Number) = num, "Done!"
__at_alert_options__(str::AbstractString,num::Number) = num, str
__at_alert_options__(num::Number,str::AbstractString) = num, str

# determine if the current system is Linux under WSL
function iswsl()
    try
        v = read("/proc/version", String)
        return occursin(r"microsoft",v)
    catch
        return false
    end
end

"""

    alert(message="Done!")

Display a cross-platform notification.

On MacOS, displays a notification window. On linux, tries to use notify-send,
zenity, kdialog or xmessage, in that order. On Windows or WSL2, uses a toast
notification.

Other platforms are not yet supported.

"""
function alert(message="Done!")
    @static if Sys.isapple()
        run(`osascript -e 'display notification "'$message'" with title "Julia"'`)
    elseif Sys.islinux()
        if iswsl()
            win_toast(message)
        elseif !isnothing(Sys.which("notify-send"))
            run(`notify-send $message`)
        elseif !isnothing(Sys.which("zenity"))
            run(pipeline(`echo $message`,`zenity --notification --listen`))
        elseif !isnothing(Sys.which("kdialog"))
            run(`kdialog --title "Julia" --passivepopup $message 10`,wait=false)
        elseif !isnothing(Sys.which("xmessage"))
            run(`xmessage $message`)
        else
            @info "Trying to send message: $message."
            @error("No program for displaying notifications available, install",
                   " 'notify-send', 'zenity', 'kdialog' or 'xmessage'.")
        end
    elseif Sys.iswindows()
        win_toast(message)
    else
        @info "Trying to send message: $message."
        @error "Unsupported operating system."
    end
end

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

end
