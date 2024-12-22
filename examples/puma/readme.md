# Puma Example

This example shows how to start Puma in a container, using `on_boot` for process readiness.

## Usage

```
> bundle exec ./application.rb
  0.0s     info: Async::Container::Notify::Console [oid=0x474] [ec=0x488] [pid=196250] [2024-12-22 16:53:08 +1300]
               | {:status=>"Initializing..."}
  0.0s     info: Application [oid=0x4b0] [ec=0x488] [pid=196250] [2024-12-22 16:53:08 +1300]
               | Controller starting...
Puma starting in single mode...
* Puma version: 6.5.0 ("Sky's Version")
* Ruby version: ruby 3.3.6 (2024-11-05 revision 75015d4c1f) [x86_64-linux]
*  Min threads: 0
*  Max threads: 5
*  Environment: development
*          PID: 196252
* Listening on http://0.0.0.0:9292
Use Ctrl-C to stop
 0.12s     info: Async::Container::Notify::Console [oid=0x474] [ec=0x488] [pid=196250] [2024-12-22 16:53:08 +1300]
               | {:ready=>true}
 0.12s     info: Application [oid=0x4b0] [ec=0x488] [pid=196250] [2024-12-22 16:53:08 +1300]
               | Controller started...
^C21.62s     info: Async::Container::Group [oid=0x4ec] [ec=0x488] [pid=196250] [2024-12-22 16:53:30 +1300]
               | Stopping all processes...
               | {
               |   "timeout": true
               | }
21.62s     info: Async::Container::Group [oid=0x4ec] [ec=0x488] [pid=196250] [2024-12-22 16:53:30 +1300]
               | Sending interrupt to 1 running processes...
- Gracefully stopping, waiting for requests to finish
=== puma shutdown: 2024-12-22 16:53:30 +1300 ===
- Goodbye!
```
