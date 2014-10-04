## fake-swapon
Setup virtual memory (swap) on Linux hosts.

## Why?
Virtual machines on [Amazon EC2](http://aws.amazon.com/ec2/) often don't enable swap. The same is true for [CoreOS](https://coreos.com/) (a docker container host). If you're trying to build stuff on either platform you are may very well run into very long build times. On [CoreOS](https://coreos.com/) this situation is likely to come up when you run "docker build" on a _Dockerfile_ to create an image. If a _RUN_ command triggers a build, things can grind to a halt. So much for quickly building new images, right?

The problem with [CoreOS](https://coreos.com/) is that it uses [btrfs](https://btrfs.wiki.kernel.org/index.php/Main_Page) (aka "Butter" file system), which doesn't support swap. But all is not lost, you can create a swap file by leveraging the [loop device](http://en.wikipedia.org/wiki/Loop_device).

fake-swapon is meant to be called manually or by setup/build scripts.

## Usage
There are no options. Just invoke fake-swapon like so:

	>sh ./fake-swapon.sh
	
fake-swapon will attempt to detect if swap already exists. This is done by checking /proc/meminfo. If no swap is found, then fake-swapon will attempt to create a swap file. On [CoreOS](https://coreos.com/) this will be accomplished via the [loop device](http://en.wikipedia.org/wiki/Loop_device); on [CoreOS](https://coreos.com/) the script will create a swap file without the old fashioned way.

## Limitations
Cleanup needs to be performed manually. And the script will have to be re-run between reboots (the system fstab will not be modified).

## Compatibility
fake-swapon can target Linux variants only. Those currently include [CoreOS](https://coreos.com/) and [CentOS](http://www.centos.org/).

## License
fake-swapon is licensed under the MIT open source license.

## Appreciation
Like this script? Let me know! You can send some kudos my way courtesy of Flattr:

[![Flattr this Bitbucket repo](http://api.flattr.com/button/flattr-badge-large.png)](https://flattr.com/submit/auto?user_id=markeissler&url=https://bitbucket.org/markeissler/fake-swapon&title=fake-swapon&language=bash&tags=github&category=software)