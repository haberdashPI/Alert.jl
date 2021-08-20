module Alert
using Base64
using Dates
using Logging
using Printf
using REPL
using MacroTools

export alert_REPL!, alert, @alert

function __init__()
    init_alert_backends()
    init_alert_REPL!()
end

# `alert` implementation
# =================================================================

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

# `@alert` implementation
# =================================================================

"""
    @alert [duration=2.0] [message="Done!"] [onerror=true] [body...]

Calls [`alert`](@ref) if `body` takes longer than `duration` (default to 2.0)
seconds to complete; Posts the alert even if `body` throws an exception so long
as `onerror=true`. 

Settings (e.g. `duration`) are specified as keyword arguments.

> NOTE: when `onerror=true` the body is run in a `try/catch` block, meaning
any variables you define inside `@alert` are local. 
"""
macro alert(args...)
    if length(args) == 0
        error("Missing body for @alert macro.")
    end
    options, body = parse_alert_args(args)
    options = NamedTuple(options)

    if get(options, :onerror, true)
        return quote
            start_time = Dates.now()
            result = nothing
            try 
                result = begin 
                    $(esc(body))
                end
            finally
                delay, msg = Alert.__at_alert_options__(;$options...)
                if !isinf(delay) && (Dates.now() - start_time) >= Dates.Millisecond(round(Int,1000delay))
                    alert(msg)
                end
            end
            
            result
        end
    else
        return quote
            start_time = Dates.now()
            result = nothing
            result = begin 
                $(esc(body))
            end

            delay, msg = Alert.__at_alert_options__(;$options...)
            if !isinf(delay) && (Dates.now() - start_time) >= Dates.Millisecond(round(Int,1000delay))
                alert(msg)
            end
        end
    end
end

function parse_alert_args(args)
    opts = []
    
    i = 0
    for outer i in 1:length(args)-1
        if @capture(args[i], var_ = body_)
            push!(opts, var => body)
        else
            break
        end
    end

    opts, args[i+1]
end

__at_alert_options__(;duration=2.0,message="Done!",onerror=true) = duration, message, onerror

"""
    alert_REPL!(;[duration=2.0], [message="Done!"])

Wraps all code passed to the REPL in an `@alert` macro with the given arguments.
Hence, if anything you run in the REPL takes longer than `duration` seconds, an
alert notification will be displayed. You can set the duration to `Inf` to turn
off the notification.

> NOTE: `onerror` must always be false; therefore no alert will be shown when a
command errors. This is a limitation of REPL design. All REPL statements are
expected to be top-level statements and inserting a `try/catch` block
automatically would prevent the assignment of global variables at the REPL.
"""
function alert_REPL!(;args...)
    if VERSION < v"1.5"
        @error "Requires Julia 1.5 or higher"
        return
    end

    repl_alert_options[] = __at_alert_options__(;args...)[1:2]
    dur = repl_alert_options[][1]
    if dur !== nothing && !isinf(dur)
        secs = @sprintf("%1.2f s", repl_alert_options[][1])
        @info "Alert will be sent if REPL line takes longer than $secs to complete. See "*
            "documentation for `Alert.alert_REPL!`"
    else
        @info "REPL alerts have been turned off."
    end
end

const repl_alert_options = Ref((Inf,"Done!"))
function with_repl_alert(ex)
    dur = repl_alert_options[][1]
    if dur !== nothing && !isinf(dur)
        Expr(:toplevel, quote
            @alert(duration=$(repl_alert_options[][1]), 
                   message=$(repl_alert_options[][2]),
                   onerror=false,
                   begin; $ex; end)
        end)
    else
        ex
    end
end

function init_alert_REPL!()
    if VERSION >= v"1.5"
        if isdefined(Base, :active_repl_backend)
            push!(Base.active_repl_backend.ast_transforms, with_repl_alert)
        else
            pushfirst!(REPL.repl_ast_transforms, with_repl_alert)
        end
    end
end

"""

    apple_backend(title="Julia", subtitle="", sound="", test=false)

Helper function to define a Script Editor backend for MacOS systems.

# Arguments
- `title::AbstractString="Julia"`: Notification title
- `subtitle::AbstractString=""`: Notification subtitle
- `sound::AbstractString=""`: Notification sound
- `test::Bool=false`: Display a sample notification when initializing

# Examples
```jldoctest
julia> mybackend = Alert.apple_backend(title="𝒥𝓊𝓁𝒾𝒶", subtitle="Alert.jl", sound="Crystal");

julia> Alert.set_alert_backend!(mybackend);

julia> alert("From a fancy backend!")
```
"""
function apple_backend(;
    title::AbstractString="Julia",
    subtitle::AbstractString="",
    sound::AbstractString="",
    test::Bool=false
)
    @static if !Sys.isapple()
        @warn "You are attempting to set a MacOS backend on a different system!"
    end

    options = ""
    options = length(title) > 0 ? options * " with title \"$title\"" : options
    options = length(subtitle) > 0 ? options * " subtitle \"$subtitle\"" : options
    options = length(sound) > 0 ? options * " sound name \"$sound\"" : options

    @debug "Current command" cmd=`osascript -e 'display notification "'message'"'$options''`

    if test
        testmsg = "Your notifications will now look like this!"
        run(`osascript -e 'display notification "'$testmsg'"'$options''`)
    end

    return message -> run(`osascript -e 'display notification "'$message'"'$options''`)
end

end
