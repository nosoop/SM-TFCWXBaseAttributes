# Custom Weapons X Base Attributes

Attributes (in Custom Attributes framework format) reimplementing features that were integral to
previous iterations of Custom Weapons.

While these are originally written with [Custom Weapons X][] in mind, there is nothing
preventing their use with other plugins.

[Custom Weapons X]: https://github.com/nosoop/SM-TFCustomWeaponsX

## Attributes

### Weapon models

Contains three different attributes: `clientmodel override`, `viewmodel override`, and
`worldmodel override`.

- Overwrites the view / worldmodel on the weapon.  `clientmodel override` takes priority and
sets both of those.
  - This plugin does not mark resources for download.  Use something like
  [this plugin][File Precacher] to handle this.
  - Viewmodels are applied on weapon switch.
- Attribute value is a full path to a model file (e.g. `models/weapons/.../c_myweapon.mdl`).

[File Precacher]: https://forums.alliedmods.net/showpost.php?p=2634602&postcount=484

## License

Released under GPLv3.
