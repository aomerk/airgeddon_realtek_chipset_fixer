# airgeddon Realtek chipset fixer

> An airgeddon plugin to fix some problematic Realtek chipsets.

This plugin for [airgeddon] tool, fix the non-standard behavior of some drivers for some Realtek chipsets used on many wireless cards.
List of the compatible working cards can be found at `airgeddon` Wiki [here]. If you are having troubles with your card using `airgeddon` and your chipset is listed below, keep reading.

#### List of known chipsets fixed with this plugin

For now, the known list of chipsets that this plugin fix to be used flawlessly with `airgeddon` tool is:

 - RTL8812AU <- present in Alfa AWUS036ACH (2.4Ghz/5Ghz - USB)
 - RTL8812BU <- present in Comfast CF-913AC (2.4Ghz/5Ghz - USB)
 - RTL8814AU <- present in Alfa AWUS1900 (2.4Ghz/5Ghz - USB)

There are more cards and devices using the chipsets listed here. We listed only some examples of cards containing these chipsets.

#### How to install an airgeddon plugin?

It is already explained on `airgeddon` Wiki on [this section] with more detail. Anyway, summarizing, it consists in just copying the `.sh` plugin file to the airgeddon's plugins directory.

Plugins system feature is available from `airgeddon>=10.0`.

#### What is fixed using this plugin?

Basically, this fix for the listed Realtek cards the ability to switch mode from monitor to managed and viceversa from airgeddon menus.

Known problems even using the plugin:

 - WPS wash scanning
 - DoS during Evil Twin attacks (while the interface is splitted into two logical interfaces)

This known problems are not related to airgeddon and can't be fixed on airgeddon's side. They are directly related to driver capabilities so for now they can't be fixed.

#### Contact / Improvements / Extension to other Realtek chipsets

If you have any other wireless card with a different Realtek chipset which is also messing up with airgeddon, feel free to contact me by [IRC] or on #airgeddon channel at Discord. Join clicking on the [Public Invitation link].

[airgeddon]: https://github.com/v1s1t0r1sh3r3/airgeddon
[here]: https://github.com/v1s1t0r1sh3r3/airgeddon/wiki/Cards%20and%20Chipsets
[this section]: https://github.com/v1s1t0r1sh3r3/airgeddon/wiki/Plugins%20System#how-can-i-install-a-plugin-already-done-by-somebody
[IRC]: https://webchat.freenode.net/
[Public Invitation link]: https://discord.gg/sQ9dgt9
