# Async::Container

Provides containers which implement parallelism for clients and servers.

[![Development Status](https://github.com/socketry/async-container/workflows/Test/badge.svg)](https://github.com/socketry/async-container/actions?workflow=Test)

## Features

  - Supports multi-process, multi-thread and hybrid containers.
  - Automatic scalability based on physical hardware.
  - Direct integration with [systemd](https://www.freedesktop.org/software/systemd/man/sd_notify.html) using `$NOTIFY_SOCKET`.
  - Internal process readiness protocol for handling state changes.
  - Automatic restart of failed processes.

## Usage

Please see the [project documentation](https://socketry.github.io/async-container/) for more details.

  - [Getting Started](https://socketry.github.io/async-container/guides/getting-started/index) - This guide explains how to use `async-container` to build basic scalable systems.

  - [Systemd Integration](https://socketry.github.io/async-container/guides/systemd-integration/index) - This guide explains how to use `async-container` with systemd to manage your application as a service.

  - [Kubernetes Integration](https://socketry.github.io/async-container/guides/kubernetes-integration/index) - This guide explains how to use `async-container` with Kubernetes to manage your application as a containerized service.

## Releases

Please see the [project releases](https://socketry.github.io/async-container/releases/index) for all releases.

### v0.27.4

  - Fix race condition where `wait_for` could modify `@running` while it was being iterated over (`each_value`) during health checks.

### v0.27.3

  - Add log for starting child, including container statistics.
  - Don't try to (log) "terminate 0 child processes" if there are none.

### v0.27.2

  - More logging, especially around failure cases.

### v0.27.1

  - Log caller and timeout when waiting on a child instance to exit, if it blocks.

### v0.27.0

  - Increased default interrupt timeout and terminate timeout to 10 seconds each.
  - Expose `ASYNC_CONTAINER_INTERRUPT_TIMEOUT` and `ASYNC_CONTAINER_TERMINATE_TIMEOUT` environment variables for configuring default timeouts.

### v0.26.0

  - [Production Reliability Improvements](https://socketry.github.io/async-container/releases/index#production-reliability-improvements)

### v0.25.0

  - Introduce `async:container:notify:log:ready?` task for detecting process readiness.

### v0.24.0

  - Add support for health check failure metrics.

### v0.23.0

  - [Add support for `NOTIFY_LOG` for Kubernetes readiness probes.](https://socketry.github.io/async-container/releases/index#add-support-for-notify_log-for-kubernetes-readiness-probes.)

### v0.21.0

  - Use `SIGKILL`/`Thread#kill` when the health check fails. In some cases, `SIGTERM` may not be sufficient to terminate a process because the signal can be ignored or the process may be in an uninterruptible state.

## Contributing

We welcome contributions to this project.

1.  Fork it.
2.  Create your feature branch (`git checkout -b my-new-feature`).
3.  Commit your changes (`git commit -am 'Add some feature'`).
4.  Push to the branch (`git push origin my-new-feature`).
5.  Create new Pull Request.

### Developer Certificate of Origin

In order to protect users of this project, we require all contributors to comply with the [Developer Certificate of Origin](https://developercertificate.org/). This ensures that all contributions are properly licensed and attributed.

### Community Guidelines

This project is best served by a collaborative and respectful environment. Treat each other professionally, respect differing viewpoints, and engage constructively. Harassment, discrimination, or harmful behavior is not tolerated. Communicate clearly, listen actively, and support one another. If any issues arise, please inform the project maintainers.
