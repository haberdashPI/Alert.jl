module Alert
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

"""

    alert(message="Done!")

Display a cross-platform notification.

On MacOS, displays a notification window. On linux, tries to use notify-send,
zenity, kdialog or xmessage, in that order. On Windows, uses a toast
notification.

Other platforms are not yet supported.

"""
function alert(message="Done!")
    @static if Sys.isapple()
        run(`osascript -e 'display notification "'$message'" with title "Julia"'`)
    elseif Sys.islinux()
        if !isnothing(Sys.which("notify-send"))
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
        win_toast("Julia", message)
    else
        @info "Trying to send message: $message."
        @error "Unsupported operating system."
    end
end

function win_toast(title, content)
    posh_script = """
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime]

    \$Template = [Windows.UI.Notifications.ToastTemplateType]::ToastImageAndText01
    [xml]\$ToastTemplate = ([Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(\$Template).GetXml())
    [xml]\$ToastTemplate = @"
    <toast launch="app-defined-string">
        <visual>
            <binding template="ToastGeneric">
                <text>$(title)</text>
                <text>$(content)</text>
            </binding>
        </visual>
    </toast>
    "@
    \$ToastXml = New-Object -TypeName Windows.Data.Xml.Dom.XmlDocument
    \$ToastXml.LoadXml(\$ToastTemplate.OuterXml)

    \$app = '$(joinpath(Sys.BINDIR,"julia.exe"))'
    \$notify = [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier(\$app)
    \$notify.Show(\$ToastXml)
    """
    open(`powershell.exe -Command -`, "w") do io
        println(io, posh_script)
    end
end

end
