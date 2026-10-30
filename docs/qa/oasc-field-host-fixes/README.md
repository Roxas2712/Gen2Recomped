# Native script lifetime and OASC menu drawing

Base: 22836638b5328c3c22685982e1f832612a370c16 (preview 20261029.3 / 0.8.60).
A native script coroutine started inside a source update must own its lifetime
across subsequent frames. ScriptRunner now creates a native root; source-created
children still borrow and retire their parent phase. Existing 48 phase, 30 Game3
callback and 133 native-effect assertions pass, including all five GBA editions.
Two added regression tests cover script/frame isolation and ROM-native frame/text
adapters. Kanto Oak dialogue and lab arrival pass on macOS with OASC Third Person,
with and without Heights. No coordinate/event/flag data were changed.

Chrome.fixedStdFrame and Window.userFrame/printPx now delegate to native imported
ROM frames and proportional fonts. Original GameShark 0.9.12's actual menu opens
and draws after OASC's physical direction code. No cheat effects are qualified.
First eye level and outdoor upward Third views pass on the same macOS host.
The separate five-edition release matrix is retained in the private OASC release.
A new Windows binary execution is not established by these macOS tests.

Publication integration: merged current fork main b61896bb before publication.
The two new regression suites and all 211 existing phase/callback/native-effect
assertions pass on that combined source without module-path overrides. The
four repaired engine files remain byte-identical to the native-tested fix.
The earlier native five-edition checks use the documented preview base plus
these repairs; this is not a new native/full-story test of every intervening
main change.
