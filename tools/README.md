Additional tools for `miatoll` devices
======================================

The tools in this folder are not strictly necessary for the basic functionality
of Ubuntu Touch on `miatoll` devices, and are recommended for advanced users
only.


enable-fm-radio.sh
------------------

This is necessary in order to expose the FM radio functionality to Ubuntu
Touch. The script takes a `super.img` Android dynamic partition image file as
input and adds a handful of binaries to the vendor sub-partition. Two of these
binaries are Qualcomm shared libraries which are taken from the system image
(it's unclear why Qualcomm/Xiaomi decided to put them in there, since they are
 device-specific!), and the other one is the [fm-bridge
program](https://gitlab.com/ubuntu-touch-xiaomi-violet/fm-bridge) which is
described more in detail
[here](http://www.mardy.it/blog/2021/12/enabling-the-fm-radio-in-ubuntu-touch.html).

### When to use it

The `enable-fm-radio.sh` tool must be used *before* installing Ubuntu Touch; it
can also be run when Ubuntu Touch is already installed, but then you'll have to
re-run the Ubuntu Touch installer anyway, since the device for some reason is
unable to recognize the new `super` partition otherwise. However, clearing the
userdata will not be necessary, so this procedure should not disrupt your
existing installation.

### Prerequisites

You must have the MIUI 10 firmware downloaded and extracted on your host
computer. If you don't have it already, you can get it from
[xiaomifirmwareupdater.com](https://xiaomifirmwareupdater.com/):
- *Redmi Note 9 Pro joyeuse:* [LINK](https://xiaomifirmwareupdater.com/archive/miui/joyeuse/)
- *Redmi Note 9s/9 Pro India curtana:* [LINK](https://xiaomifirmwareupdater.com/archive/miui/curtana)
- *Redmi Note 9 Pro Max excalibur:* [LINK](https://xiaomifirmwareupdater.com/archive/miui/excalibur/)
Make sure you select the **fastboot** type and the **Android 10.0** version for
your correct region.

Unpack the archive, and notice the file `images/super.img`: that's the file
you'll have to pass to the tool.

You also need the `lpunpack` and `lpmake` tools from
[Google](https://android.googlesource.com/platform/system/extras/+/master/partition_tools/);
if you cannot find ready binaries for them, the simplest way to build them is
by using [this repository](https://github.com/LonelyFool/lpunpack_and_lpmake).

### How to run it

This is the simplest part, after you have sorted out all the dependencies: just
head to your `images/` directory (where `super.img` is located) and type:

    enable-fm-radio.sh super.img

After some seconds, it will ask you for your root password in order to
loop-mount the vendor image and change it. Once the program is done, you should
have a file called `super.new.img` in the current directory. With your device
connected in fastboot mode, type:

    fastboot flash super super.new.img

and wait for it to flash. Do not reboot, instead start the UBports installer.
If you have Ubuntu Touch currently running on your device, make sure that the
"Bootstrap" and "Wipe userdata" options are **not** checked, or you'll lose all
your current data.
