# Omarchy Box

> [!WARNING]
> Omarchy Box is a work in progress. It is not yet ready for production use, and the interface may change without notice.

Build and run [Omarchy](https://omarchy.org/) in a virtual machine to test the build, try out new features, or explore the system without affecting your main system.

## Requirements

Omarchy Box is known to work on macOS and Linux. It has not been tested on Windows.

Apple Silicon & ARM64 Linux hosts are supported, but the guest is always `x86_64`. Emulation mode must therefore used, which is significantly slower than the virtualization used by `x86_64` hosts.

A few dependencies are required. Be sure to install them before running `omarchy-box`:
- `qemu` (specifically `qemu-system-x86_64`)
- `scp`
- `ssh`
- `sshpass`

On some hosts, like Ubuntu, `qemu` doesn't install any systems by default. In this case an additional package like `qemu-system-x86` is required for the `qemu-system-x86_64` command to be available. Other hosts, like macOS with `brew`, installing `qemu` is sufficient to get all `qemu` systems.

## Installation

```bash
git clone https://github.com/omarchy/omarchy-box.git
cd omarchy-box
```

## Usage

### Installing Omarchy / Build Testing

```bash
./omarchy-box build
```

This will download the required base image, start a virtual machine, and install Omarchy. If the build is successful, the virtual machine will be left running for you to explore.

Each time `./omarchy-box` is run, the virtual machine will be reset to the base image, and Omarchy will be reinstalled. This is especially useful when making changes to Omarchy in a fork and testing them out. Each time you push changes, re-run `./omarchy-box` with `OMARCHY_BOX_REPO` and `OMARCHY_BOX_REF` set to attempt a rebuild.

If anything goes wrong, you can clean up with `./omarchy-box clean`, which restores the original state. This removes everything in the `data` directory, including the base image and any built images, so be sure to back up anything you want to keep.

### Running Omarchy

```bash
./omarchy-box start
```

This will use the last build of Omarchy to start the virtual machine.

### Login

The username and password are both `arch`.

### Environment Variables
You can customize the behavior of Omarchy Box using environment variables:
- `OMARCHY_BOX_IMAGE`: The image to run the virtual machine from. By default this will create an overlay image from the base image called `omarchy-build.qcow2`, but this can be overridden to use any image in the data directory.
- `OMARCHY_BOX_CPUS`: The number of CPU cores to allocate to the virtual machine. Defaults to 4.
- `OMARCHY_BOX_RAM`: The amount of RAM to allocate to the virtual machine, in MB. Defaults to 4096.
- `OMARCHY_BOX_SSH_PORT`: The port to use for SSH access to the virtual machine. Defaults to 2222.
- `OMARCHY_BOX_REPO`: The GitHub repository to clone. Defaults to the default `OMARCHY_REPO` as set in Omarchy `boot.sh`.
- `OMARCHY_BOX_REF`: The branch or ref to check out. Defaults to the default `OMARCHY_REF` as set in Omarchy `boot.sh`.
- `OMARCHY_BOX_BARE`: If set to `true`, only basic essential system tools will be installed, instead of the full Omarchy system.

See [`omarchy-box`](./omarchy-box) for additional options.

## License

Omarchy Box is released under the [MIT License](https://opensource.org/licenses/MIT).
