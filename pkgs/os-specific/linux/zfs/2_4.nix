{
  callPackage,
  lib,
  nixosTests,
  stdenv,
  fetchpatch,
  ...
}@args:

(callPackage ./generic.nix args {
  # You have to ensure that in `pkgs/top-level/linux-kernels.nix`
  # this attribute is the correct one for this package.
  kernelModuleAttribute = "zfs_2_4";

  kernelMinSupportedMajorMinor = "4.18";
  kernelMaxSupportedMajorMinor = "7.0";

  # this package should point to the latest release.
  version = "2.4.1";

  extraPatches = [
    # Linux 7.0 compat commits backported from openzfs/zfs master, since v2.4.1
    # predates 7.0 support. All are kernel-API shims; none touch on-disk code.
    (fetchpatch {
      name = "zfs-linux-7.0-setlease-handler.patch";
      url = "https://github.com/openzfs/zfs/commit/168023b60316badde853a8264b3bdbe071bab0c1.patch";
      hash = "sha256-l2yw18o15s4ZEMEQqUPQ2jowSAzzkZhLXbIeEJsiUnY=";
    })
    (fetchpatch {
      name = "zfs-linux-7.0-blk-queue-rot.patch";
      url = "https://github.com/openzfs/zfs/commit/204de946ebd1e540efe0067f3b880daf0795c1fb.patch";
      hash = "sha256-uLriUZK5ZS6FydhMqeJvWU+UCD01h3NAfjrqHLn8x2M=";
    })
    (fetchpatch {
      name = "zfs-linux-7.0-fs-context-mount-api.patch";
      url = "https://github.com/openzfs/zfs/commit/0f608aa6ca323e503cba6843320b1dab3b004896.patch";
      hash = "sha256-0XKQ3tUGLHKvASBtBiyoRp50CcqvkG7Dulrkprp7Qn4=";
    })
    (fetchpatch {
      name = "zfs-linux-7.0-posix-acl-xattr.patch";
      url = "https://github.com/openzfs/zfs/commit/d34fd6cff3ac882a0f26cb6bdd5a5b1c189c0e82.patch";
      hash = "sha256-GDMbarsZrzxulCURbk7wCtGbCS74i7ahfDERR1zNuXg=";
    })
    # openzfs/zfs@8518e3e8 ("autoconf: Remove copy-from-user-inatomic API
    # checks") isn't applied as a fetchpatch because its file-deletion hunk
    # targets a post-SPDX-header version of the .m4 that v2.4.1 predates. The
    # equivalent surgery is done in postPatch below.
    (fetchpatch {
      name = "zfs-linux-7.0-setlease-directories.patch";
      url = "https://github.com/openzfs/zfs/commit/d8c08a1cea6428fa37b3a6585150b10dedfd79b8.patch";
      hash = "sha256-2vmJsGVqvn/aX2C8zkjgS0ucH6cqLACsbW/SUhzmUrI=";
    })
    (fetchpatch {
      name = "zfs-linux-7.0-lsm-mount-options.patch";
      url = "https://github.com/openzfs/zfs/commit/4155d1533e1ac22057c9d21d57b28f8d36e59359.patch";
      hash = "sha256-Sh35SsGNLOvNUqCncIsSotPqBTTk1DPEmUMipW2ycaM=";
    })
  ];

  tests = {
    inherit (nixosTests.zfs) series_2_4;
  }
  // lib.optionalAttrs stdenv.isx86_64 {
    inherit (nixosTests.zfs) installer;
  };

  maintainers = with lib.maintainers; [
    adamcstephens
    amarshall
  ];

  hash = "sha256-gapM2PNVOjhwGw6TAZF6QDxLza7oqOf1tpj7q0EN9Vg=";
}).overrideAttrs
  (prevAttrs: {
    # Prepended to the existing postPatch so these run before generic.nix's
    # META sanity grep and any substitutions it does.
    postPatch = ''
      # Widen META's Linux-Maximum so generic.nix's postPatch grep passes now
      # that we advertise 7.0 support.
      substituteInPlace META \
        --replace-fail 'Linux-Maximum: 6.19' 'Linux-Maximum: 7.0'

      # Manually apply the kernel.m4 hunks of openzfs@8518e3e (see extraPatches
      # comment above): drop the two copy-from-user-inatomic autoconf calls and
      # remove the now-unreferenced .m4 file.
      sed -i \
        -e '/ZFS_AC_KERNEL_SRC___COPY_FROM_USER_INATOMIC/d' \
        -e '/ZFS_AC_KERNEL___COPY_FROM_USER_INATOMIC/d' \
        config/kernel.m4
      rm config/kernel-copy-from-user-inatomic.m4
    ''
    + prevAttrs.postPatch;
  })
