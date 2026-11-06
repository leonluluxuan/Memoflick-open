# Source release checklist

## Included in this repository

- Offline app and widget source copied from the formal Xcode project
- Formal publishing Team IDs, bundle IDs, and App Group IDs replaced with
  public placeholder identifiers
- Old HTML references, MVP material, `.DS_Store`, and root-level prototypes excluded
- Local Xcode user state excluded
- Noncommercial license and attribution documents added
- Contributor, security, trademark, and third-party asset guidance added
- Privacy statement, code of conduct, issue templates, and pull-request
  template added

## Maintainer checks before a signed distribution

- Audit bundled visual assets and confirm redistribution rights; replace any
  asset whose rights cannot be documented.
- Build an unsigned simulator archive from this directory.
- Test upgrade from the existing App Store release and confirm local data and
  widget migration.
- Review Apple's current signing, privacy, and App Store requirements before
  distributing a signed build.
