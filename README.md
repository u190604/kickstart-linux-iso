# kickstart-linux-iso
Repository contains bash scripts to build custom ISO from a source ISO.
The custom ISO includes a Kickstart file that runs an unattended installation.
Installation starts immediately when the VM boots with the ISO mounted and CD-ROM as the first boot device.

The script works on Linux or WSL.

Kickstart notes:
- Creates user `aglu` with `wheel` access.
- Installs an SSH public key for the user and ensures `/home/aglu/.ssh/authorized_keys` is created with correct permissions.

```
chmod +x build-alma-iso.sh

VOLUME_LABEL="CUSTOM_ALMA" ./alma/build-alma-iso.sh \
  ./alma/source.iso \
  ./alma/custom_alma.iso
```
