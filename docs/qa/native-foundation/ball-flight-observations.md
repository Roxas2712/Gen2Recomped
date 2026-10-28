# Native ball flight observations

A player send-out ball was always exposed with rotation zero, even while the
native clock advanced its throw. Existing presentation consumers use the
unwrapped throw angle to place the ball between the trainer's hand and its
landing point, and to transition from grip size to flight size. A constant
angle therefore pins that progress at zero until the cell changes to open.

Expose the player send-out's actual `phaseFrame / send.frames` in the existing
unwrapped angular range. Opening resets the presentation angle; opponent and
capture observations keep their existing semantics. This is a read-only scalar
projection: native x/y, timing, sound, mon reveal, catch math and queue clocks
are not changed, and the native painter remains as before. It also follows
imported send-out durations instead of deriving progress from fitted pixels.

Current-main frozen `89bf734b9d` passes176 CPU groups including1808 new checks
across five GBA editions and alternate imported durations. Repeated observations
leave the actual native timeline equal to an independently advanced native
control. The identical fixture on native predecessor `981b6f57`, run
`839d5839f5`, reproduces288 failures out of1808 checks. Older-public composition
`d54354c682` passes67 groups including the same1808 checks; its existing native
ball/stage/capture prerequisite is retained and only the scalar hunk is applied.
No newer native simulation/controller body is overlaid. A new fork workflow
covers the observation, stage/capture identity and native Gen2 scene regressions;
hosted CI remains separate from these local results.

The real unchanged-mod flight/size capture is being qualified separately.
The completed earlier Ruby menu/terrarium smoke is not flight acceptance.
QA uses only owned profiles/copies with the20GiB free-space floor. Player
profiles and private mod files are untouched.
