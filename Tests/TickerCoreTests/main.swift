// Test entry point. Each suite is a plain function; add new ones here.
runConfigTests()
runStatusPageTests()
runOutageMonitorTests()
runOutageHistoryTests()
runMessageComposerTests()
await runPollEngineTests()

Check.report()
