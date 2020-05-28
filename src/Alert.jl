module Alert

@static if Sys.iswindows()
    using PyCall
    const wintoast = PyNULL()
    function __init__()
        copy!(wintoast, pyimport_conda("win10toast","win10toast","conda-forge"))
    end
end

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
        wintoast.ToastNotifier().show_toast("Julia",message,
            icon_path=joinpath(@__DIR__,"..","images","julia.ico"))
    else
        @info "Trying to send message: $message."
        @error "Unsupported operating system."
    end
end

end