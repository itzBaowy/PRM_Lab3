# AI review output — Codex, 2026-11-11

Scope: local diff at `62b842e` and tests at `8df1606`. This is an AI-assisted local review, **not a GitHub PR review**. User explicitly requested direct main delivery. A separate external PR review remains a submission requirement unless lecturer accepts this alternative.

CR-01 (bug/UI): `_WeekGrid` in lib/screens/workspace_screens.dart scrolls its time-slot column with the days. DESIGN S02 explicitly requires fixed slot labels. Replace with a shared-scroll table with fixed labels and equal row heights; test horizontal scrolling at narrow widths.

CR-02 (bug/data integrity): ImportScreen permits edits after the preview is generated. The confirmation imports the old preview, so displayed fields can disagree with committed semester/schedule. Invalidate preview whenever any form input changes, and preserve parsed preview on save failure.

CR-03 (bug/concurrency): LinkVm creates a cloud link and calls workspace.attachLink outside WorkspaceVm.perform. Manual marks/close can race the attach, and a failed local save leaves a live cloud link with no locally tracked ID. Serialize create/attach in WorkspaceVm, stop the newly created link on local failure, and avoid reopening existing sessions implicitly.

CR-04 (performance/state): receiveLinks invokes perform every eight seconds even with no open links. _drain persists and increments revision even when all submissions were already imported. This clears UI errors/success and creates needless local writes/sync conflicts. Poll only actionable sessions, persist only changed results, bound network waits, and preserve feedback when nothing changes.

CR-05 (architecture/lifecycle): ProfileScreen performs notification-target resolution and logout orchestration; it reads BuildContext after awaited cleanup. Move domain lookup and sign-out eligibility to WorkspaceVm; capture service references before await and move cleanup to an injected coordinator.

CR-06 (security/reliability): `private` rules allow any authenticated owner of getAfter session to read via a write-oriented helper. Simplify read to current owner and restrict getAfter to batch writes. Exercise cross-user access, verified membership, timed visit, invalid code, closed session, duplicate submit, workspace revision and Storage ownership in emulators.

CR-07 (test gap): Domain tests pass but there are no narrow-width screen/golden tests, no required-reason sheet validation or freeze-column assertion. Add widget interaction and overflow checks, using explicit synthetic fixtures outside lib.

CR-08 (integration): Android template does not apply Google Services/Crashlytics plugins. Configure them conditionally on actual google-services.json so unconfigured APK shows setup state and configured APK initializes Firebase. Do not fabricate config credentials.
