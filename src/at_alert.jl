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

