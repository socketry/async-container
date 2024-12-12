# Exec Child Example

This example demonstrates how to execute a child process using the `exec` function in a container.

## Usage

Start the main controller:

```
> bundle exec ./start
  0.0s     info: AppController [oid=0x938] [ec=0x94c] [pid=96758] [2024-12-12 14:33:45 +1300]
               | Controller starting...
 0.65s     info: Jobs [oid=0x8e8] [ec=0x8fc] [pid=96763] [2024-12-12 14:33:45 +1300]
               | Starting jobs...
 0.65s     info: Jobs [oid=0x8e8] [ec=0x8fc] [pid=96763] [2024-12-12 14:33:45 +1300]
               | Notifying container ready...
 0.65s     info: Jobs [oid=0x8e8] [ec=0x8fc] [pid=96763] [2024-12-12 14:33:45 +1300]
               | Jobs running...
 0.65s     info: Web [oid=0x8e8] [ec=0x8fc] [pid=96760] [2024-12-12 14:33:45 +1300]
               | Starting web...
 0.65s     info: Web [oid=0x8e8] [ec=0x8fc] [pid=96760] [2024-12-12 14:33:45 +1300]
               | Notifying container ready...
 0.65s     info: Web [oid=0x8e8] [ec=0x8fc] [pid=96760] [2024-12-12 14:33:45 +1300]
               | Web running...
 0.09s     info: AppController [oid=0x938] [ec=0x94c] [pid=96758] [2024-12-12 14:33:45 +1300]
               | Controller started...
```

In another terminal: `kill -HUP 96758` to cause a blue-green restart, which causes a new container to be started with new jobs and web processes:

```
 9.57s     info: Jobs [oid=0x8e8] [ec=0x8fc] [pid=96836] [2024-12-12 14:33:54 +1300]
               | Starting jobs...
 9.57s     info: Web [oid=0x8e8] [ec=0x8fc] [pid=96833] [2024-12-12 14:33:54 +1300]
               | Starting web...
 9.57s     info: Jobs [oid=0x8e8] [ec=0x8fc] [pid=96836] [2024-12-12 14:33:54 +1300]
               | Notifying container ready...
 9.57s     info: Web [oid=0x8e8] [ec=0x8fc] [pid=96833] [2024-12-12 14:33:54 +1300]
               | Notifying container ready...
 9.57s     info: Jobs [oid=0x8e8] [ec=0x8fc] [pid=96836] [2024-12-12 14:33:54 +1300]
               | Jobs running...
 9.57s     info: Web [oid=0x8e8] [ec=0x8fc] [pid=96833] [2024-12-12 14:33:54 +1300]
               | Web running...
```

Once the new container is running and the child processes have notified they are ready, the controller will stop the old container:

```
 9.01s     info: Async::Container::Group [oid=0xa00] [ec=0x94c] [pid=96758] [2024-12-12 14:33:54 +1300]
               | Stopping all processes...
               | {
               |   "timeout": true
               | }
 9.01s     info: Async::Container::Group [oid=0xa00] [ec=0x94c] [pid=96758] [2024-12-12 14:33:54 +1300]
               | Sending interrupt to 2 running processes...
 9.57s     info: Web [oid=0x8e8] [ec=0x8fc] [pid=96760] [2024-12-12 14:33:54 +1300]
               | Exiting web...
 9.57s     info: Jobs [oid=0x8e8] [ec=0x8fc] [pid=96763] [2024-12-12 14:33:54 +1300]
               | Exiting jobs...
```

The new container continues to run as expected:

```
19.57s     info: Web [oid=0x8e8] [ec=0x8fc] [pid=96833] [2024-12-12 14:34:04 +1300]
               | Web running...
19.57s     info: Jobs [oid=0x8e8] [ec=0x8fc] [pid=96836] [2024-12-12 14:34:04 +1300]
               | Jobs running...
```
