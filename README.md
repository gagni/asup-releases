# aSup releases

Binaries, add-ons and the signed update catalog of aSup. This repository holds no source code.

- `catalog.json` lists the latest version of aSup and of each add-on, with the SHA-256 and size of every file.
- `catalog.json.sig` is the Ed25519 signature of `catalog.json`. aSup checks it with the public key compiled into it, then checks each downloaded file against the catalog.

Latest catalog: <https://github.com/gagni/asup-releases/releases/latest/download/catalog.json>
