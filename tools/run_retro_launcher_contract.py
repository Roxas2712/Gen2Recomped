"""Run the ROM-free launcher contract without starting LOVE or importing games."""
from pathlib import Path
import json
import shutil
import sys
from qa_storage import qa_source, qa_run

root = Path(__file__).resolve().parents[1]
qa_source(root)
runtime = shutil.which('luajit')
if not runtime:
    raise SystemExit('LuaJIT is required for the headless launcher contract.')
qa_source(runtime)
syntax = ['main.lua', 'conf.lua', 'src/cloud/Http.lua', 'src/cloud/RetroCloud.lua',
          'src/cloud/NativeAccount.lua', 'src/cloud/DeveloperProjects.lua',
          'src/import/AccountWorkspace.lua', 'src/import/DeveloperWorkspace.lua',
          'src/import/LauncherStorage.lua', 'src/import/LauncherSidebar.lua', 'src/import/CartridgeDownload.lua',
          'src/import/cartridge_download_worker.lua', 'src/core/Music.lua', 'src/core/Sound.lua',
          'src/import/LauncherCommunity.lua', 'src/import/RomImporter.lua',
          'src/core/Game.lua', 'src/core/SaveData.lua', 'src/storage/SaveResume.lua',
          'src/import/ResumeWorkspace.lua', 'src/import/SaveHistoryWorkspace.lua', 'src/mods/ModProfiles.lua',
          'src/import/LauncherModProfiles.lua', 'src/mods/LauncherMods.lua', 'src/storage/BankItems.lua',
          'src/storage/GlobalPokedex.lua', 'src/cloud/BankExchange.lua', 'src/import/BankPages.lua', 'src/import/BankWorkspace.lua',
          'src/import/ImageBounds.lua', 'src/storage/AccountStorage.lua', 'src/storage/ProfileFs.lua']
source = '\n'.join('assert(loadfile(' + json.dumps(path) + '))' for path in syntax)
qa_run([runtime, '-e', source], cwd=root, check=True)
suites = '''launcher_sequence cart_designer launcher_seasons launcher_community
pokemon_bank mod_profiles mod_download bank_workspace launcher_mod_profiles
retro_overlay cloud_running_slot developer_account developer_workspace native_account
account_workspace private_http developer_projects mod_profile_recovery retro_overlay_main
window_frame window_frame_async portable_input_hooks touch_orientation_bug633
save_resume resume_workspace save_resume_capture save_resume_slot save_history_workspace launcher_audio_handoff bank_exchange'''.split()
suites.extend(['native_preview','account_storage','account_profiles'])
for suite in suites:
    qa_run([runtime, str(root / 'tests/engine' / (suite + '.lua'))], cwd=root, check=True)
