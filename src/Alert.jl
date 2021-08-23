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

include("core.jl")
include("at_alert.jl")
include("alert_repl.jl")
include("apple.jl")