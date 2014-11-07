## fake-swapon
Setup temporary virtual memory (swap) on CoreOS and CentOS Linux hosts.

## Why?
Virtual machines on [Amazon EC2](http://aws.amazon.com/ec2/) often don't enable swap. The same is true for [CoreOS](https://coreos.com/) (a docker container host). If you're trying to build stuff on either platform you are may very well run into very long build times. On [CoreOS](https://coreos.com/) this situation is likely to come up when you run "docker build" on a _Dockerfile_ to create an image. If a _RUN_ command triggers a build, things can grind to a halt. So much for quickly building new images, right?

The problem with [CoreOS](https://coreos.com/) is that it uses [btrfs](https://btrfs.wiki.kernel.org/index.php/Main_Page) (aka "Butter" file system), which doesn't support swap. But all is not lost, you can create a swap file by leveraging the [loop device](http://en.wikipedia.org/wiki/Loop_device).

fake-swapon is meant to be called manually or by setup/build scripts.

## Installation
To install fake-swapon, just copy the script to a suitable directory (like /usr/local/bin) as the superuser. Then, execute the following permissions changes:

```sh
>cd /path/to/install/directory
>chown root:root fake-swapon.sh
>chmod 700 fake-swapon.sh
>ln -s fake-swapon.sh fake-swapon
```

After the execute bit has been set on the fake-swapon.sh script, you will be able to call the script without having to invoke a shell first and then pass the script as an argument.

**NOTE: fake-swapon requires BASH 4.2 or greater.**

## Usage
Keep in mind that fake-swapon targets its owned managed swap only, it will not manage or return results for swap added through other means.

**NOTE: fake-swapon must be run as the superuser (root).**

For help, just invoke fake-swapon with the help (-h|--help) option:

```sh
>fake-swapon --help
```

There are three option categories:

* (-l | --list-swap) list swap
* (-a | --add-swap) add swap
* (-r | --remove-swap) remove swap

### List Swap
To list all _wired_ and _unwired_ swap, use the (-l|--list-swap) option:

```sh
	>fake-swapon --list-swap
	Analyzing system for fake-swap status...
    Detected Linux variant: CoreOS [472.0.0]
    
    ? Swap Id     Type                  Size    Used
    * abcdfh      (loop)                1.4G    ??
      d3rnfo      partition (loop)      1024M   13.4M
      npt4u8      partition (loop)      1024M   0B
      
    --
    * preceding Swap Id denotes unwired swap
```

In the above example, _unwired_ swap is marked with an asterisk (*). This indicates a swap file that was created previously, and is no longer in use. This can happen if the system has been rebooted. Ideally, you will want to clean up _unwired_ swap files. One suggestion is to simply run fake-swapon with the `-r` option at system startup to remove all swap files before creating new ones.

### Add Swap
Before adding swap, fake-swapon will attempt to detect if swap already exists. This is done by checking /proc/meminfo. If no swap is found, then fake-swapon will attempt to create a swap file. On [CoreOS](https://coreos.com/) this will be accomplished via the [loop device](http://en.wikipedia.org/wiki/Loop_device); on [CentOS](http://www.centos.org/) the script will create a standard swap file (that is, without a loop device). Other Linux distributions are not currently supported.

When swap already exists (either system swap or temporary fake swap), additional swap will not be added without prompting the user for confirmation. Prompting can be skipped with the `-f` option.

Adding swap with the default swap size (1024MB):

```sh
	>fake-swapon --add-swap
```

You can also specify a custom swap size with the `-s` option:

```sh
	>fake-swapon --add-swap --swap-size 2048
```

Custom swap sizes are specified in megabytes (MB). Do not add a unit following the number.

### Remove Swap
Both _wired_ and _unwired_ swap can be removed by specifying the `-r` option. When doing so, *ALL* swap managed by fake-swapon will be removed.

```sh
	>fake-swapon --remove-swap
```

If the `-r` option is specified without the `-i` option (identifying a single swap to remove) and multiple swap files are detected, then fake-swapon will prompt the user before continuing. Prompting can be skipped with the `-f` option.

To remove a single swap file, first obtain the swap id using the `-l` option. Then use the `-i` option to specify id of the swap to remove:

```sh
	>fake-swapon --remove-swap --swap-id fz34sk
```

## Limitations
There are some limitations to the fake-swapon temporary swap utility:

* cleanup needs to be performed manually (just use the `-r` command line option)
* the script will have to be re-run between reboots (the system fstab will not be modified)

## Compatibility
fake-swapon can target Linux variants only. Supported Linux distributions currently include:

* [CoreOS](https://coreos.com/)
* [CentOS](http://www.centos.org/)

fake-swapon requires BASH 4.2 or higher.

## License
fake-swapon is licensed under the MIT open source license.

## Appreciation
Like this script? Let me know! You can send some kudos my way courtesy of Flattr:

[![Flattr this Bitbucket repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=markeissler&url=https://bitbucket.org/markeissler/fake-swapon&title=fake-swapon&language=bash&tags=github&category=software)