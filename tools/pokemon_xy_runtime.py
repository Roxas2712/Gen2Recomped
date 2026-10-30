"""Relocatable, game-data-free 3DS runtime shipped beside game.love.

Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
"""
import hashlib
import json
import os
from pathlib import Path
import platform
import struct

FILES_MAC = {'compiler': 'bin/3dsrecomp', 'cc': 'bin/cc',
         'bridge': 'lib/libascendant_3ds_bridge.dylib',
         'python': 'python/bin/python3.12',
         'loader': 'vulkan/libvulkan.1.dylib',
         'driver': 'vulkan/libMoltenVK.dylib',
         'icd': 'vulkan/MoltenVK_icd.json'}
FILES_WINDOWS = {'compiler':'bin/3dsrecomp.exe','cc':'compiler/bin/clang.exe',
                 'bridge':'lib/ascendant_3ds_bridge.dll','python':'python/python.exe',
                 'loader':'vulkan/vulkan-1.dll','driver':'vulkan/vk_swiftshader.dll',
                 'icd':'vulkan/vk_swiftshader_icd.json'}
FILES = FILES_WINDOWS if platform.system()=='Windows' else FILES_MAC


def load(path):
    root = Path(path).resolve(strict=True)
    metadata = json.loads((root/'runtime.json').read_text())
    windows=platform.system()=='Windows' and platform.machine().lower() in {'amd64','x86_64'}
    mac=platform.system()=='Darwin' and platform.machine()=='arm64'
    if (metadata.get('schema') != 1 or metadata.get('bridge_protocol') != 1 or
            metadata.get('platform') != ('windows-x64' if windows else 'macos-arm64') or
            not (windows or mac) or
            not isinstance(metadata.get('id'), str) or len(metadata['id']) != 64):
        raise ValueError('The bundled 3DS runtime is incompatible with this device.')
    version = tuple(int(n) for n in (platform.mac_ver()[0] or '0').split('.')[:2])
    minimum = tuple(int(n) for n in metadata.get('minimum_macos','15.0').split('.')[:2])
    if mac and version < minimum:
        raise ValueError('This bundled 3DS graphics runtime requires macOS '+metadata.get('minimum_macos','15.0')+' or newer.')
    for relative in FILES.values():
        if not (root/relative).is_file():
            raise ValueError('The bundled 3DS runtime is incomplete: '+relative)
    return root, metadata


def fingerprint(rom_hash, runtime_id):
    return hashlib.sha256((rom_hash+':'+runtime_id).encode()).hexdigest() if runtime_id else rom_hash


def completed(binary, rom_hash, runtime_id):
    """A killed linker must not become a cache hit on the next import."""
    try:
        marker = json.loads(binary.with_suffix('.complete.json').read_text())
        if marker.get('rom') != rom_hash or marker.get('runtime') != runtime_id:
            return False
        with binary.open('rb') as stream:
            return hashlib.file_digest(stream, 'sha256').hexdigest() == marker.get('sha256')
    except (OSError, ValueError):
        return False


def finish(binary, rom_hash, runtime_id):
    with binary.open('rb') as stream:
        header = stream.read(32)
        if platform.system()=='Windows':
            if header[:2]!=b'MZ':raise ValueError('The compiler did not produce a Windows game DLL.')
            stream.seek(60);offset=struct.unpack('<I',stream.read(4))[0];stream.seek(offset);pe=stream.read(24)
            if len(pe)!=24 or pe[:4]!=b'PE\0\0' or struct.unpack_from('<H',pe,4)[0]!=0x8664 or not(struct.unpack_from('<H',pe,22)[0]&0x2000):
                raise ValueError('The compiler did not produce a Windows x64 game DLL.')
        elif len(header) != 32 or struct.unpack('<IiiI', header[:16]) != (0xfeedfacf, 0x100000c, 0, 6):
            raise ValueError('The compiler did not produce an arm64 macOS game library.')
        stream.seek(0)
        digest = hashlib.file_digest(stream, 'sha256').hexdigest()
    marker = binary.with_suffix('.complete.json')
    pending = marker.with_suffix('.pending')
    pending.write_text(json.dumps({'schema': 1, 'rom': rom_hash, 'runtime': runtime_id, 'sha256': digest})+'\n')
    pending.replace(marker)


def environment(root, work):
    env = dict(os.environ)
    try:
        jobs = max(1, min(8, int(env.get('RETRO_3DS_BUILD_JOBS', '2'))))
    except ValueError:
        jobs = 2
    env.update(CC=str(root/FILES['cc']), ZIG_LIB_DIR=str(root/'compiler/lib'),
               ZIG_GLOBAL_CACHE_DIR=str(work/'compiler-cache/global'),
               ZIG_LOCAL_CACHE_DIR=str(work/'compiler-cache/local'),
               RETRO_3DS_BUILD_JOBS=str(jobs),
               RUST_LOG='info,cranelift_jit=warn')
    # Compiler processes use the bundled C toolchain even with a minimal GUI
    # PATH. No shell setup, Homebrew or Xcode installation is required.
    env['PATH'] = os.pathsep.join([str(root/'bin'),str(root/'compiler/bin'),str(root/'lib'),env.get('PATH','/usr/bin:/bin')])
    return env
