# Systemd Integration

This guide explains how to use `async-container` with systemd to manage your application as a service.

## Service File

Install a template file into `/etc/systemd/system/`:

```
# my-daemon.service
[Unit]
Description=My Daemon

[Service]
Type=notify
ExecStart=bundle exec my-daemon

[Install]
WantedBy=multi-user.target
```

Ensure `Type=notify` is set, so that the service can notify systemd when it is ready.

## Graceful Shutdown

Controllers handle `SIGTERM` gracefully (same as `SIGINT`). This ensures proper graceful shutdown when systemd stops the service.

**Note**: systemd sends `SIGTERM` to services when stopping them. With graceful handling, your application will have time to clean up resources, finish in-flight requests, and shut down gracefully before systemd escalates to `SIGKILL` (after the timeout specified in the service file).
