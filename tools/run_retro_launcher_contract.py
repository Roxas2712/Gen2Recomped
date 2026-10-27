"""Run the ROM-free launcher contract without starting LOVE or importing games."""
from pathlib import Path
import argparse
import json
import os
import shutil
import sys
from qa_storage import qa_source, qa_run

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--legacy-bank-source', type=Path,
                    help='Optional trusted KASC source directory; pure model/store only, no game or user saves.')
parser.add_argument('--suite', action='append', help='Run only a named suite; repeat to select multiple suites.')
args = parser.parse_args()
qa_source(root)
if args.legacy_bank_source:
    args.legacy_bank_source = args.legacy_bank_source.resolve()
    qa_source(args.legacy_bank_source)
runtime = shutil.which('luajit')
if runtime:
    qa_source(runtime)
    runtime = [runtime]
elif os.environ.get('RETRO_QA_LUA_LIBRARY'):
    qa_source(Path(os.environ['RETRO_QA_LUA_LIBRARY']))
    qa_source(sys.executable)
    runtime = [sys.executable, str(root / 'tools/run_lua_check.py')]
else:
    raise SystemExit('LuaJIT or RETRO_QA_LUA_LIBRARY is required for the headless launcher contract.')
syntax = ['src/link/ArenaReplay.lua','src/ui/PlayerRole.lua','src/cloud/AccountBadge.lua','src/import/FirstRun.lua','src/storage/SyncStatus.lua','src/translation/LauncherCatalog.lua','src/cloud/Play.lua','src/link/FriendLink.lua','src/link/FriendTrade.lua','src/ui/FriendsMenu.lua','src/ui/ProfileAvatar.lua','src/world/RemotePlayers.lua','src/cloud/ArenaShop.lua','src/import/ArenaShopView.lua','src/link/CloudNet.lua','src/link/ArenaProof.lua','src/link/ArenaTeam.lua','src/link/ArenaResults.lua','src/link/LinkState.lua','src/link/LinkBattle.lua','src/storage/LeagueEgg.lua','src/cloud/League.lua','main.lua', 'conf.lua', 'src/cloud/Http.lua', 'src/cloud/RetroCloud.lua',
          'src/cloud/NativeAccount.lua', 'src/cloud/Tournaments.lua', 'src/link/CloudArena.lua', 'src/import/TournamentWorkspace.lua', 'src/cloud/Task.lua', 'src/cloud/Presence.lua', 'src/cloud/GiftCodes.lua', 'src/storage/GiftReward.lua', 'src/storage/GiftPokemon.lua', 'src/storage/GiftGenerator.lua', 'src/storage/GiftItems.lua', 'src/import/GiftDesigner.lua', 'src/import/DataLiteral.lua', 'src/import/CloudSync.lua', 'src/import/CacheFs.lua', 'src/storage/GameCache.lua', 'src/cloud/DeveloperProjects.lua',
          'src/import/AccountWorkspace.lua', 'src/import/DeveloperWorkspace.lua', 'src/import/LauncherCobblemon.lua', 'src/storage/CartridgeCloud.lua', 'src/storage/WonderReward.lua',
          'src/import/LauncherStorage.lua', 'src/import/LauncherSidebar.lua', 'src/import/CartridgeDownload.lua',
          'src/import/cartridge_download_worker.lua', 'src/core/Music.lua', 'src/core/Sound.lua',
          'src/import/LauncherCommunity.lua', 'src/import/LauncherPresentation.lua', 'src/import/CartridgeImages.lua', 'src/import/CartridgeBatch.lua', 'src/import/ModCatalogue.lua', 'src/mods/ModSearch.lua', 'src/mods/ModAccess.lua', 'src/mods/ModPreflight.lua', 'src/import/RomImporter.lua',
          'src/core/Game.lua', 'src/core/SaveData.lua', 'src/storage/SaveResume.lua',
          'src/import/ResumeWorkspace.lua', 'src/import/SaveHistoryWorkspace.lua', 'src/mods/ModProfiles.lua',
          'src/import/LauncherModProfiles.lua', 'src/mods/LauncherMods.lua', 'src/storage/BankItems.lua',
          'src/storage/GlobalPokedex.lua', 'src/cloud/BankExchange.lua', 'src/import/BankPages.lua', 'src/import/BankWorkspace.lua',
          'src/import/ImageBounds.lua', 'src/storage/AccountStorage.lua', 'src/storage/ProfileFs.lua',
          'src/storage/LuaData.lua', 'src/storage/BankInterop.lua', 'src/mods/SharedStorage.lua',
          'src/mods/Api3.lua', 'src/mods/PlaythroughStorage.lua', 'src/import/BankInterchangeWorkspace.lua']
syntax.extend(['src/translation/Service.lua','src/translation/CommunityCatalog.lua','src/translation/AccountErrors.lua','src/translation/worker.lua'])
source = '\n'.join('assert(loadfile(' + json.dumps(path) + '))' for path in syntax)
if not os.environ.get('RETRO_QA_LUA_LIBRARY') or shutil.which('luajit'):
    qa_run([*runtime, '-e', source], cwd=root, check=True)
suites = '''header_account account_presence launcher_edition_theme first_run sync_status launcher_storage launcher_locale suspend_private_import launcher_sequence cart_designer launcher_seasons launcher_community
pokemon_bank mod_profiles mod_download bank_workspace launcher_mod_profiles
retro_overlay cloud_running_slot cloud_sync_rng gen3_battle_terrain_init suspend_journal suspend_store suspend_continue developer_account developer_workspace native_account
account_workspace private_http developer_projects mod_profile_recovery retro_overlay_main
window_frame window_frame_async portable_input_hooks touch_orientation_bug633
save_resume resume_workspace save_resume_capture save_resume_slot save_history_workspace launcher_audio_handoff bank_exchange'''.split()
suites.extend(['friends_menu','friend_trade','friend_play','remote_players','arena_shop','cloud_net','relay_rejection','native_preview','account_storage','account_profiles','bank_interop',
               'api3_storage_transactions','api3_playthrough_storage','bank_portrait','api3_compat','mod_catalogue','mod_access','mod_preflight','launcher_presentation','cartridge_batch','launcher_cobblemon','cartridge_cloud','wonder_reward','game_cache','device_session','gift_codes','gift_editor','presence','tournaments','league','arena_battle_proof'])
suites.append('arena_replay')
suites.append('nds_party_codec')
suites.append('bank_verification')
suites.append('origin_records')
suites.extend(['friend_maps', 'friend_activity', 'friend_chat', 'friend_wager'])
if args.suite:
    unknown = set(args.suite) - set(suites)
    if unknown:
        parser.error('Unknown suites: ' + ', '.join(sorted(unknown)))
    suites = list(dict.fromkeys(args.suite))
if os.environ.get('RETRO_QA_LUA_LIBRARY') and not shutil.which('luajit'):
    command = [sys.executable, str(root / 'tools/run_lua_batch.py')]
    for path in syntax:
        command.extend(['--syntax', path])
    for suite in suites:
        command.extend(['--suite', str(root / 'tests/engine' / (suite + '.lua'))])
    if args.legacy_bank_source:
        command.extend(['--legacy-bank-source', str(args.legacy_bank_source)])
    qa_run(command, cwd=root, check=True)
else:
    for suite in suites:
        command = [*runtime, str(root / 'tests/engine' / (suite + '.lua'))]
        if suite == 'bank_interop' and args.legacy_bank_source:
            command.append(str(args.legacy_bank_source))
        qa_run(command, cwd=root, check=True)
if 'launcher_locale' in suites:
    qa_run([sys.executable, str(root/'tools/check_launcher_locale.py')], cwd=root, check=True)
print(json.dumps(dict(passed=True, suites=len(suites), syntaxChecks=len(syntax))), flush=True)
