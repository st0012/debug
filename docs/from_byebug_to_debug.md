I hope this post can help you feel more comfortable switching from `byebug` to [`ruby/debug`](https://github.com/ruby/debug), or learn why you shouldn't.

Disclaimers:

- I'm not as experienced with `byebug` as I'm with `ruby/debug`. So please let me know if I listed incorrect/outdated information.
- Its purpose is to help Ruby developers decide whether to switch to `ruby/debug` (in general, yes). To learn more about `ruby/debug`'s specific usages, please check its [official documentation](https://github.com/ruby/debug).
- It doesn't contain all the features but should already cover most of them.

# Advantages of ruby/debug

Before we get into individual features, I want to quickly mention some advantages of `ruby/debug`:

- Colorized output

    <img width="50%" src="https://dev-to-uploads.s3.amazonaws.com/uploads/articles/ir3yykmwcaw3ct6h7y54.png">

- [Backtrace with method/block arguments](#backtrace)
- It doesn't have the same compatibility issue with Zeitwerk as [byebug has](https://github.com/deivid-rodriguez/byebug/issues/564)
- Its debugger statements (`binding.b[reak]`, `debugger`) and breakpoint commands can execute commands
- [Powerful tracers](#tracer) like `trace object <obj>` and `trace exception`
- [Specialized `catch` and `watch` breakpoints](#setting-a-breakpoint)
- [Convenient remote debugging and VSCode integration](#remote-debugging)
    - [About setting it up with VSCode](https://dev.to/st0012/setup-rubydebug-with-vscode-1b7c)

# Disadvantages of ruby/debug

- Stops all threads when the program is suspended and doesn't allow controlling individual threads
- Doesn't have `pry` integration like `pry-byebug`
- No per-project configuration
- Doesn't work well with Fiber yet

In general, I think most Ruby developers should switch from `byebug` to `ruby/debug` unless these disadvanges seriously affect you.

## Installation

Both `byebug` and `ruby/debug` can be installed as a gem.

And although Ruby `3.1` comes with `ruby/debug` `v1.4`, I recommend always using its latest release.

|| byebug | debug |
|---|---|---|
| Supported Ruby version | 2.5+ | 2.6+ |
| Gem install | `gem install byebug` | `gem install debug` |
| Bundler | `gem "byebug"` | `gem "debug"` |
| Dependencies | No | `irb`, `reline` |
| Has C extension | Yes | Yes |

## Start

Both `byebug` and `ruby/debug` can be used with their executables and debugger statements, `ruby/debug` can also be started
by requiring specific files.

|| byebug | debug |
|---|---|---|
| Via executable | `byebug foo.rb` | `rdbg foo.rb` |
| Via debugger statement | `byebug` | `binding.break`, `binding.b`, `debugger` (the same) |
| Via requiring | No | `require "debug/start"` |

## User Experience Features

Having colorized output is one major advantage of `ruby/debug`.

|| byebug | debug |
|---|---|---|
| Colorizing | No | Yes |
| Command history | Yes | Yes |
| Help command | `h[elp]` | `h[elp]` |
| Edit source file | `edit` | `edit` |

## Evaluation

|| byebug | debug |
|---|---|---|
| Execute debugger commands | `<cmd>` | `<cmd>`
| Avoid expression/command conflicts | `eval <expr>` | `pp <expr>`, `p <expr>`, or `eval <expr>`

## Flow Control & Frame Navigation

|| byebug | debug |
|---|---|---|
| Step in | `s[tep]` | `s[tep]` |
| Step over | `n[ext]` | `n[ext]` |
| Finish | `fin[ish]` | `fin[ish]` |
| Move to `<id>` frame | `f[rame] <id>` | `f[rame] <id>` |
| Move up a frame | `up` | `up` |
| Move down a frame | `down` | `down` |
| Move up n frames | `up <n>` | No |
| Move down n frames | `down <n>` | No |
| Continue the program | `c[ontinue]` | `c[ontinue]` |
| Quit the debugger | `q[uit]` | `q[uit]` |
| Kill the program | `kill` | `kill` |

## Thread Control

|| byebug | debug |
|---|---|---|
| Thread suspension | Only the current thread | All threads |
| List all threads | `th[read] l` | `th[read]` |
| Switch to thread | `th[read] switch <id>` | `th[read] <id>` |
| Stop a thread | `th[read] stop <id>` | No |
| Resume a thread | `th[read] resume <id>` | No |


## Breakpoint

### Breakpoints management

|| byebug | debug |
|---|---|---|
| List all breakpoints | `info breakpoints` | `b[reak]` |
| Set a breakpoint | `b[reak] ...` | `b[reak] ...` |
| Delete a breakpoint | `del[ete] <id>` | `del[ete] <id>` |
| Delete all breakpoints | `del[ete]` | `del[ete]` |

### Setting a breakpoint

|| byebug | debug |
|---|---|---|
| On line | `b[reak] <line>` | `b[reak] <line>` |
| On file:line | `b[reak] <file>:<line>` | `b[reak] <file>:<line>` |
| On a method | `b[reak] <class>#<method>` | `b[reak] <class>#<method>` |
| With a condition | `b[reak] ... if <expr>` | `b[reak] ... if: <expr>` |
| With a path condition | No | `b[reak] ... path: /path/` |
| To run a command and continue | No | `b[reak] ... do: <cmd>` |
| To run a command before stopping | No | `b[reak] ... pre: <cmd>` |
| Exception breakpoint | No | `catch <ExceptionClass>` |
| Instance variable watch breakpoint | No | `watch <@ivar>` |


## Information

### Backtrace

|| byebug | debug |
|---|---|---|
| Show backtrace | `where`, `backtrace`, `bt` | `backtrace`, `bt` |
| Show method/block arguments in backtrace | No | Yes |
| Filter backtrace | No | `bt /regexp/` |
| Limit the number of backtrace | No | `bt <n>` |

### Varibles/Constants

|| byebug | debug |
|---|---|---|
| Show local varibales | `var local` | `info l` |
| Show instance varibales | `var instance` | `info i` |
| Show global varibales | `var global` | `info g` |
| Show constants | `var const` | `info c` |
| Show only arguments | `var args` | No (included in `info l`) |
| Filter varibles/constants by names | No | `info ... /regexp/` |

### Methods

While `debug` doesn't have a dedicated command to list an object's methods, it has a `ls` command that's similar to
`irb` or `pry`'s.

|| byebug | debug |
|---|---|---|
| `obj.methods` | `method instance obj` | No |
| `obj.methods(false)` | `method obj.class` | `ls obj` |

## Tracer

|| byebug | debug |
|---|---|---|
| Line tracer | `set linetrace` | `trace line` |
| Global variable tracer | `tarcevar` | No |
| Allow multiple tracers | No | Yes |
| Method call tracer | No | `trace call` |
| Exceptions tracer | No | `trace exception` |
| Ruby object tracer | No | `trace object <expr>` |
| Filter tracing output | No | `trace ... /regexp/` |
| Disable tracer | `set linetrace false` | `trace off [tracer type]` |
| Disable the specific tracer | No | `trace off <id>` |

## Configuration

|| byebug | debug |
|---|---|---|
| List all configs | No | `config` |
| Show a config | `show <name>` | `config show <name>` |
| Set a config | `set <name> <value>` | `config set <name> <value>` |
| RC file name | `.byebugrc` | `.rdbgrc` (or `.rdbgrc.rb` for Ruby script) |
| RC file locations | `$HOME` and project root | `$HOME` |

## Remote Debugging

|| byebug | debug |
|---|---|---|
| Connect via TCP/IP | Yes | Yes |
| Connect via Unix Domain Socket | No | Yes |
| Support [Debug Adapter Protocol (DAP)](https://microsoft.github.io/debug-adapter-protocol/specification) | No | Yes |
| Support [Chrome DevTools Protocol (CDP)](https://chromedevtools.github.io/devtools-protocol/) | No | Yes |

## References

- [Debugger commands comparison sheet](https://docs.google.com/spreadsheets/d/1TlmmUDsvwK4sSIyoMv-io52BUUz__R5wpu-ComXlsw0/edit#gid=0) by @ko1
- [Byebug's official guide](https://github.com/deivid-rodriguez/byebug/blob/master/GUIDE.md)
- [ruby/debug's official documentation](https://github.com/ruby/debug)
