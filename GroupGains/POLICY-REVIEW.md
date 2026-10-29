# Release review: 0.9.0 / 20261029.4

## Changes

Discovery stores characters by the existing normalized character-and-realm key. Short local names and their realm-qualified forms share one peer, search reply, incoming rate limit and response limit. The latest accepted packet supplies progress and time; a known realm-qualified address is kept for display and native invitations. Same-named characters on different realms remain separate. Friend authorization and queued search deduplication use the same identity comparison. Group and ignore filtering still applies.

The finder invitation control now displays a simple + with its Invite to group tooltip. It still requires a user click and validates a live eligible match, native invitation permissions, combat state and cooldowns.

Initialization immediately requests a full search over enabled audiences, independently of tracker visibility. It replaces the initial unsolicited heartbeat and retains a pending search during combat, instances or chat locks. Startup is guarded against duplicate timers. Existing eight-second search cooldowns, bounded queues, reply throttles, two-second sends and approximately sixty-second periodic searches remain. Everyone remains opt-in.

Objective progress defaults to Game objective complete (iquestupdate); objective completion defaults to Window close (AuctionWindowClose). Quest completion remains Orc Male Congratulations02. Previous defaults are migrated once; other choices and enable/mute/channel settings are preserved. Audio continues to reference installed game files only.

Both tracker and journal part selectors show a completed-task count such as [1/7], or [Done] for a nonempty completed part. Completed parts stay gray and selectable. Counts refresh from the existing character progress model.

## Policy review

Reviewed the changes against Blizzard's [UI Add-On Development Policy](https://eu.forums.blizzard.com/en/wow/t/wow-user-interface-add-on-development-policy/1642) on October 29, 2026. This is a scoped implementation review, not Blizzard certification. The changes retain supported addon messages, native audio playback and user-clicked invitations. No protected API workaround, public-chat discovery fallback, new advertising, payment feature or external network connection is introduced. Character normalization reduces duplicate traffic. Search traffic remains bounded and pauses under game restrictions. Code is original and readable; no Questie/TomTom code or recordings were copied or redistributed.

## Packaging and verification

109 simulated-client and export tests passed, including both alias arrival orders, distinct realms, ignore/group exclusion, matching counts, queued-search deduplication, shared rate limits, initial searches with both tracker visibility states, deferred login searches, opt-outs, invitation clicks, sound defaults/migration and part-selector updates. These are not live WoW visual, audio or server tests.

Guide revision fbb17ca10f974649 is retained: 91 baseline chapters, 585 parts, 4,358 baseline tasks and 45 Durotar race/class variants. No website files are changed. Only dist and an archive are prepared; no game installation or CurseForge publication is modified.
