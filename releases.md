# Releases

## Unreleased

  - Improve container signal handling reliability by using `Thread.handle_interrupt` except at known safe points.
  - Improved logging when child process fails and container startup.
