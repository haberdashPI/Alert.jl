# Alert

[![Project Status: Active – The project has reached a stable, usable state and is being actively developed.](https://www.repostatus.org/badges/latest/active.svg)](https://www.repostatus.org/#active)
[![Build Status](https://github.com/haberdashPi/Alert.jl/workflows/ci/badge.svg)](https://github.com/haberdashPI/Alert.jl/actions?query=workflow%3A%22CI%22+branch%3Amaster)


Alert provides a cross-platform means of displaying a notification to the user in Julia. It
should work on MacOS, Windows 10 (even under WSL2) and many flavors of Linux. This is handy
for long-running scripts. You can also use an extension
([AlertPushover](https://github.com/haberdashPI/AlertPushover.jl)) to send notifications to
your phone or a webapp when working remotely.

There are three ways to use alert:

1. Call `alert()` after a long-running piece of code.
2. Put long-running code inside the `@alert` macro.
3. Call `alert_REPL!` and any long-running code sent to the REPL will display a notification.

Before using `alert()` at the end of a long-running script, it would be good to
test that it actually works on your system: some linux distros may not have an
appropriate program installed to display the notification. Loading `Alert`
should warn you if it can't find an appropriate executable to send the
notification. Just read the error message that is displayed to see what program
you need to install.

Table of Contents:
<!-- TOC -->

- [The alert function](#the-alert-function)
- [The @alert macro](#the-alert-macro)
- [The REPL hook](#the-repl-hook)
- [Troubleshooting](#troubleshooting)
- [Extensions](#extensions)

<!-- /TOC -->

## The `alert()` function

To use `alert()` just add it to some long-running code.

```julia

using Alert

for i in 1:10_000
    long_running_function()
end

alert("Your julia script is finished!")
```

## The `@alert` macro

The `@alert` macro displays a message if the code passed to it runs for longer
than 2 seconds (or a custom value). This is especially handy when using
[`ProgressMeter`](https://github.com/timholy/ProgressMeter.jl), like so.

```julia
@alert @showprogress for i in 1:10_000
    long_running_function()
end
```

## The REPL hook

In Julia 1.5 or greater, if you want any long-running command at the REPL to
send a notification, you can use `alert_REPL!`. It takes the same arguments as
`@alert` and will wrap any code passed to the Julia REPL in a call to `@alert`.

You can add the following to your `startup.jl` file to have it work in every
Julia session.

```julia
try
    using Alert
    alert_REPL!()
catch e
    @warn e.msg
end
```

## Troubleshooting

- **Notification fails to display on Windows**: check to make sure you have Notifications turned on in "Notifications & actions" in your OS settings. ![Window of the Windows 10 "Notifications & actions"](https://aws1.discourse-cdn.com/business5/uploads/julialang/optimized/3X/b/5/b55776f64fa7dae966a3773bca40e3627a1a480b_2_960x750.png)

## Extensions

If you want to use `alert` remotely or in an online IDE, where you can't get local UX
notifications, you can use [AlertPushover](https://github.com/haberdashPI/AlertPushover.jl).