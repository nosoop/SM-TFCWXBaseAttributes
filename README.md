# Custom Weapons X Base Attributes

Attributes (in Custom Attributes framework format) reimplementing features that were integral to
previous iterations of Custom Weapons.

While these are originally written with [Custom Weapons X][] in mind, there is nothing
preventing their use with other plugins.

[Custom Weapons X]: https://github.com/nosoop/SM-TFCustomWeaponsX

## Dependencies

In addition to Custom Attributes, you'll need:

- [Econ Data](https://github.com/nosoop/SM-TFEconData)
- [TF2Utils](https://github.com/nosoop/SM-TFUtils) (0.11.0 or newer)

## Attributes

### Weapon models

`viewmodel_override.smx` provides three different attributes: `clientmodel override`,
`viewmodel override`, and `worldmodel override`.

- Overwrites the view / worldmodel on the weapon.  `clientmodel override` takes priority and
sets both of those.
  - **This plugin does not mark resources for download.**  Attribute values are evaluated at
  runtime; it has no knowledge of possible values on level startup.  Use something like this
  [File Precacher][] plugin to mark your custom resources for download by other game clients.
  - Make sure you've set `sv_pure` to allow custom files.  (Either set it to 0 or -1, or set it
  to 1 and modify `cfg/pure_server_whitelist.txt` to specify the paths to your custom assets.
  If you use a strict pure setting, do keep in mind that you cannot ensure that players haven't
  replaced your custom models with something else on their client.)
  - Viewmodels are applied on weapon switch.
- Attribute value is a full path to a model file (e.g. `models/weapons/.../c_myweapon.mdl`).

It also implements `arm model override`, which allows for visual replacements of the arm models.
Animations are inherited from the original arms.  This is quite cursed.

[File Precacher]: https://forums.alliedmods.net/showpost.php?p=2634602&postcount=484

## License

Released under GPLv3.
