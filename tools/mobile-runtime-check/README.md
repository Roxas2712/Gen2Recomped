# Native mobile runtime capacity

Android currently links the vendored `android/<ABI>/libluajit.a` archives.
Source/header edits do not replace those archives. This builder creates new
isolated stock (60 captures) and experimental extended (120 captures) libraries,
matching public headers, an Android interpreter and a linked C API probe for
each selected ABI. It preserves the vendored source, existing binaries and
LuaJIT copyright notice. No application or player data is copied.

The source version is bound to the existing Android headers. Compilation uses
NDK 25.2.9519653 in CI, API 23 by default and Lua-5.2 compatibility in both
variants. Linux uses a matching 32/64-bit host toolchain; macOS supports the
64-bit cross-builds. The command layout follows the upstream
[LuaJIT cross-compilation instructions](https://luajit.org/install.html).

```sh
python3 tools/mobile-runtime-check/build_android.py \
  --ndk /path/to/android/ndk/25.2.9519653 \
  --abi arm64-v8a --output .local/qa/android-runtime-test/candidate
```

Every candidate includes the existing closure/debug/bytecode probe and a C API
executable linked against the same headers and static library. The builder
checks target ELF architecture and records hashes. Its reports explicitly keep
`targetExecutionQualified` and `releaseSelectable` false: Android execution and
the actual LÖVE/JNI/thread/FFI boundary must be exercised before packaging can
select a candidate. The regular application keeps its current runtime. Preview
packaging selects an extended component only after the matching app-host gates
pass for all shipping architectures.

The workflow also executes both x86-64 candidates on an owned API-30 Android
emulator through `check_android_target.py`. Transfers are hash-checked before
the closure/debug/bytecode/GC and linked C API tests run. The tool requires an
explicit emulator serial, writes only its unique temporary directory, and
removes its own files afterward. ARM and 32-bit execution remain separate
requirements. This standalone VM test does not replace the LÖVE/JNI/thread/FFI
host gate, so its report also keeps release selection disabled.

iOS uses separately built Apple framework slices and interpreter-mode
qualification. Switch still needs a rebuilt runtime and target execution. These
build artifacts establish neither full platform parity nor original-mod
startup, rendering or gameplay acceptance. Local QA uses the shared 20 GiB
reserve and owned output leases.

## Actual Android app-host gate

`qualify_android_love.py build` copies the tracked, fully materialized Android
source into one owned QA directory, selects x86-64 there and builds two distinct
test APKs through the existing Gradle/LÖVE/JNI project. Each uses the exact
stock-60 or extended-120 archive and matching headers from a candidate receipt.
The source checkout and normal application runtime are preserved. A fresh
application ID and provider authority prevent overlap with an installed game.
Only the small ROM-free payload is embedded; no mod, cartridge or player save
is copied.

```sh
python3 tools/mobile-runtime-check/qualify_android_love.py build \
  --build /path/to/android-runtime/candidate \
  --output .local/qa/android-love-build/candidate
python3 tools/mobile-runtime-check/qualify_android_love.py run \
  --serial emulator-5554 --build .local/qa/android-love-build/candidate \
  --output .local/qa/android-love-run/candidate
```

The build needs the pinned SDK/NDK, JDK 17 and a complete Android checkout.
The run refuses physical devices and existing app installations. It installs
only its fresh test apps on an explicit emulator, checks interpreter/JIT,
closure/debug/bytecode/GC behavior inside the real LÖVE 11.5 host, calls an FFI
callback, executes a separate LÖVE thread VM and verifies filesystem bindings.
Reports are written inside each test app's private directory; only installations
created by that invocation are stopped and uninstalled. Candidate, APK and
source hashes bind the evidence to the actual built inputs.

The `Android LÖVE runtime host` workflow builds and executes arm64-v8a,
armeabi-v7a and x86_64 app candidates. ARM binaries run through the emulator's
native bridge; the probe requires the reported Lua architecture to match the
selected ABI. LÖVE's deliberate default of JIT-off on ARM is preserved. Both
interpreter and explicitly enabled JIT closure boundaries are exercised.
Reports describe emulation, not physical-device acceptance.

## iOS interpreter components and guarded preview selection

`build_ios.py` builds device arm64 plus arm64/x86_64 simulator archives from the
same immutable LuaJIT source revision used by the desktop candidate. Stock and
extended variants have matching public headers. Both explicitly disable JIT,
including simulator builds, and retain LuaJIT's copyright notice.
`qualify_ios_love.py` installs them in an owned prepared LÖVE source copy and
executes both variants in fresh simulator apps. It checks Lua closures, the
actual exported C API, FFI callbacks, separate LÖVE thread VMs and filesystem
bindings. Only its explicitly created simulator and applications are removed.

`component.py` stages components from passing, hash-linked candidate receipts.
Android requires every shipping ABI. iOS requires an actual arm64 simulator
host, all three built slices, and interpreter-only receipts. Architecture and
archive-byte checks bind the generated XCFramework to the qualified libraries.
Missing host gates, changed libraries/headers, mismatched source trees and
incomplete ABI coverage are rejected. Component manifests keep physical-device
acceptance separate from these checks.

```sh
python3 tools/mobile-runtime-check/component.py --platform android \
  --engine-root /path/to/frozen-engine \
  --candidate /path/to/arm64 --candidate /path/to/armv7 --candidate /path/to/x64 \
  --output /path/to/new/android-component
python3 tools/package_native_port.py --platform android \
  --engine-root /path/to/frozen-engine --payload /path/to/preview.love \
  --runtime-component /path/to/new/android-component/component.json \
  --release-id YYYYMMDD.N --engine-version X.Y.Z --out /path/to/new/package
```

The iOS commands use `--platform ios`; provide its framework/host candidate
directory to the component stager. Build tools may be newer than a frozen
engine checkout, but payload source/release/profile checks still require exact
agreement with that checkout. The payload is never restamped or repacked.
Mobile qualification neither bundles private mods nor establishes a complete
gameplay or physical GPU/input acceptance for KASC/VASC.
