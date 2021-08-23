"""
    apple_alert!(;title="Julia", subtitle="", sound="")

Use a nicer appearing backend for MacOS systems.

# Arguments
- `title::AbstractString="Julia"`: Notification title
- `subtitle::AbstractString=""`: Notification subtitle
- `sound::AbstractString=""`: Notification sound
- `clear::Bool`: if true, clears all apple_alert settings and reverts to default
  backend

# Examples
```jldoctest
julia> Alert.apple_alert!(title="𝒥𝓊𝓁𝒾𝒶", subtitle="Alert.jl", sound="Crystal");

julia> alert("From a fancy backend!")
```
"""
function apple_alert!(;clear=false,kwds...)
    if clear
        set_alert_backend!()
    else
        Alert.set_alert_backend!(apple_backend(;kwds...))
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
