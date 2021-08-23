
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
            pushfirst!(Base.active_repl_backend.ast_transforms, with_repl_alert)
        else
            pushfirst!(REPL.repl_ast_transforms, with_repl_alert)
        end
    end
end

