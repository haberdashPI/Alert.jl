# Alert

Alert provides a cross-platform means of displaying a notification to the user in Julia. It
should work on MacOS, Windows 10 (even under WSL2) and many flavors of Linux. This is handy
for long-running scripts.

There are three ways to use alert:

1. Call `alert()` after a long-running piece of code.
2. Put long-running code inside the `@alert` macro.
3. Call `alertREPL` and any long-running code sent to the REPL will display a notification.

Before using `alert()` at the end of a long-running script, it would be good to
test that it actually works on your system: some linux distros may not have
an appropriate program installed to display the notification. If it doesn't
work, just read the error message that is displayed to see what program you need
to install.

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

In Julia 1.5 or greater, if you want any long-running command at the REPL to send a
notification, you can use `alertREPL`. It takes the same arguments as `@alert` and will wrap
any code passed to the Julia REPL in a call to `@alert`.

You can add the following to your `startup.jl` file to have it work in every Julia
session.

```julia
try
    using Alert
    alertREPL()
catch e
    @warn e.msg
end
```

## Common Issues

If you do not receive a notification on Windows. Please ensure you have Notifications turned on in "Notifications & actions"

See

![](https://aws1.discourse-cdn.com/business5/uploads/julialang/optimized/3X/b/5/b55776f64fa7dae966a3773bca40e3627a1a480b_2_960x750.png)

