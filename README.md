# kickstart-linux-iso
Repository contains bash scripts to build custom iso file from source iso.
Custom iso contains custom kickstart file which run unattended installation of Linux distro
Installation starts immediatly whne VM started and if iso file is mounted to VM and if cdrom is first boot device

```
chmod +x build-alma-iso.sh

VOLUME_LABEL="CUSTOM_ALMA" ./alma/build-alma-iso.sh \
  ./alma/source.iso \
  ./alma/custom_alma.iso
```