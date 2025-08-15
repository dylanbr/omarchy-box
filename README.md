# Omarchy Box

Run [Omarchy](https://omarchy.org/) in a virtual machine to test or explore without touching your main system.

Warning: Omarchy Box is a work in progress. It is not yet ready for production use, and the interface may change in the future.

## Requirements

Omarchy Box is known to work on macOS and Linux. It has not been tested on Windows.

Although it should work on Apple Silicon / Linux ARM64, an x86_64 is always used. This means it will run in emulation mode, which is significantly slower than running natively.

A few dependencies are required. Be sure to install them before running `omarchy-box`:
- `qemu` (specifically `qemu-system-x86_64`)
- `scp`
- `ssh`
- `sshpass`

## Installation and Usage

```bash
git clone https://github.com/omarchy/omarchy-box.git
cd omarchy-box
./omarchy-box
```

This will download the required base image, start a virtual machine, and install Omarchy. If the build is successful, the virtual machine will be left running for you to explode.

Each time `./omarchy-box` is run, the virtual machine will be reset to the base image, and Omarchy will be reinstalled.

If anything goes wrong, you can clean up with `./omarchy-box clean`, which will restore `omarchy-box` to its original state. This removes everything that was downloaded, including the base image.

The username and password are both `arch`.

### Environment Variables
You can customize the behavior of Omarchy Box using environment variables:
- `OMARCHY_BOX_CPUS`: The number of CPU cores to allocate to the virtual machine. Defaults to 4.
- `OMARCHY_BOX_RAM`: The amount of RAM to allocate to the virtual machine, in MB. Defaults to 4096.
- `OMARCHY_BOX_SSH_PORT`: The port to use for SSH access to the virtual machine. Defaults to 2222.
- `OMARCHY_BOX_REPO`: The GitHub repository to clone. Defaults to the default `OMARCHY_REPO` as set in Omarchy `boot.sh`.
- `OMARCHY_BOX_REPO`: The branch or ref to check out. Defaults to the default `OMARCHY_REF` as set in Omarchy `boot.sh`.

See [`omarchy-box`](./omarchy-box) for additional options.

## License

Omarchy Box is released under the [MIT License](https://opensource.org/licenses/MIT).
