# Alert

Alert provides a cross-platform means of displaying a notification to the user
in Julia. It should work on MacOS, Windows 10 or Linux. This is handy for
long-running scripts; just add `alert()` to the end of the script, and go work
on something else until you see the notification. To use it just run `alert`,
like so.

```julia

using Alert

for i in 1:10_000
    long_running_function()
end

alert("Your julia script is finished!")
```

Before using `alert()` at the end of a long-running script, it would be good to
test that it actually works on your system: e.g. some linux distros may not have
an appropriate program installed to display the notification. If it doesn't
work, just read the error message that is displayed to see what program you need
to install.

The package also provides `@alert` which can be used to notify you when a block
of code has finished, if it takes longer than 2 seconds (or any custom value).
This is especially handy when using `ProgressMeter`, like so.

```julia
@alert @showprogress for i in 1:10_000
    long_running_function()
end
```