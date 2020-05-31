module Alert

export alert

"""

    alert(message="Done!")

Display a cross-platform notification.

On MacOS, displays a notification window. On linux, tries to use notify-send,
zenity, kdialog or xmessage, in that order. On windows, uses a toast
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
