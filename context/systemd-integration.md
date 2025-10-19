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
