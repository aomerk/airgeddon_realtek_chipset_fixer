# This is still under construction

# airgeddon Realtek chipset fixer

> An airgeddon plugin to fix some problematic Realtek chipsets.

This plugin for [airgeddon] tool, fix the non-standard behavior of some drivers for some Realtek chipsets used on many wireless cards.
List of the compatible working cards can be found at `airgeddon` Wiki [here]. If you are having troubles with your card using `airgeddon` and your chipset is listed below, keep reading.

#### List of known chipsets fixed with this plugin

For now, the known list of chipsets that this plugin fix to be used with `airgeddon` tool is:

 - RTL8812AU <- present in Alfa AWUS036ACH and on many other wireless cards (2.4Ghz/5Ghz - USB)

#### How to install an airgeddon plugin?

It is already explained on `airgeddon` Wiki on [this section] with more detail. Anyway, summarizing, it consists in just copying the `.sh` plugin file to the airgeddon's plugins directory.

Plugins system feature is available from `airgeddon>=10.0`.

[airgeddon]: https://github.com/v1s1t0r1sh3r3/airgeddon
[here]: https://github.com/v1s1t0r1sh3r3/airgeddon/wiki/Cards%20and%20Chipsets
[this section]: https://github.com/v1s1t0r1sh3r3/airgeddon/wiki/Plugins%20System#how-can-i-install-a-plugin-already-done-by-somebody