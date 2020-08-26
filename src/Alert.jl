module Alert
using Base64
using Dates
using Printf
using REPL

const default_backend = Ref{Function}()
const alert_backend = Ref{Function}()
"""

    set_alert_backend!(fn)

Defines a custom backend for how `alert` sends messages to the user.
The arugment should be a function of one arugment (a string) which displays
the message to the user via some native UX api call.

If you wish to revert to the default backend, call this mehtod with no arguments.

"""
set_alert_backend!(fn::Function) = alert_backend[] = fn
set_alert_backend!() = alert_backend[] = default_backend[]

export alertREPL, alert, @alert

function __init__()
    if VERSION >= v"1.5"
        pushfirst!(REPL.repl_ast_transforms, with_repl_alert)
    end

    default_backend[] = if Sys.isapple()
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
            @error("There is no program for displaying notifications available, install"*
                " 'notify-send', 'zenity', 'kdialog' or 'xmessage'; otherwise, messages "*
                "sent by `alert` will not display.")
        end
    elseif Sys.iswindows()
        win_toast
    else
        @error "Unsupported operating system, no messages sent by `alert` will be "*
            "displayed. Consider using `AlertPushover`."
    end

    alert_backend[] = default_backend[]
end

const repl_alert_options = Ref((Inf,"Done!"))
function with_repl_alert(ex)
    if !isinf(repl_alert_options[][1])
        Expr(:toplevel, quote
            @alert $(repl_alert_options[][1]) $(repl_alert_options[][2]) $ex
        end)
    else
        ex
    end
end

"""
    alertREPL([duration=2.0], [message="Done!"])

Wraps all code passed to the REPL in an `@alert` macro with the given arguments. Hence,
if anything you run in the REPL takes longer than `duration` seconds, an alert notification
will be displayed. You can set the duration to `Inf` to turn off the notification.
"""
function alertREPL(args...)
    repl_alert_options[] = __at_alert_options__(args...)
    dur = repl_alert_options[][1]
    if !isinf(dur)
        secs = @sprintf("%1.2f s", repl_alert_options[][1])
        @info "Alert will be sent if REPL line takes longer than $secs to complete. See "*
            "documentation for `Alert.alertREPL`"
    else
        @info "REPL alerts have been turned off."
    end
end

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
        result = $(esc(body))
        delay, msg = Alert.__at_alert_options__($options...)
        if !isinf(delay) && (Dates.now() - start_time) > Dates.Millisecond(round(Int,1000delay))
            alert(msg)
        end

        result
    end
end

__at_alert_options__() = 2.0, "Done!"
__at_alert_options__(str::AbstractString) = 2.0, str
__at_alert_options__(num::Number) = convert(Float64,num), "Done!"
__at_alert_options__(str::AbstractString,num::Number) = convert(Float64,num), str
__at_alert_options__(num::Number,str::AbstractString) = convert(Float64,num), str

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
alert(message="Done!") = alert_backend[](message)

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
