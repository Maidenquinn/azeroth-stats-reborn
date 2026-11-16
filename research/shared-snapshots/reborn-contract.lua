-- Isolated synthetic Reborn contracts; never loaded by the installed addon.
local A, M = AzerothStatsReborn, SharedBackupResearch
local function check(ok, label)
    TEST_COUNT = TEST_COUNT + 1
    assert(ok, label)
end
local db = {
    schema = A.schema,
    game = A.game,
    sequence = 23,
    runs = {
        {
            id = "reborn-fixture-23",
            nativeRunId = "azs:r12345678",
            class = "monk",
            status = "interrupted",
            partial = true,
            values = { damage = 1234 },
            accounted = {},
            events = {},
            meters = {},
            recordsReset = true,
            trendsReset = true,
            nemesisReset = true,
            sumResets = { kills = true },
            reborn = {
                game = A.game,
                contract = 1,
                endless = true,
                loadout = { abilities = { { key = "auto_shot", rank = 4 } } },
                segments = { { start = 10, stop = 20, damage = { displayAmount = 1234 } } },
            },
        },
    },
    totals = { runs = 50, sum = { damage = 987654 } },
    classes = {},
    settings = { language = "fr", rebornResetRunId = "azs:r12345678", rebornWindow = 120 },
    migrations = {},
}
check(A.ValidateDatabase(db), "Reborn research fixture validates")
local pool = M.new()
local old = assert(M.save(pool, db, false))
local frozen = assert(M.restore(pool, old))
db.runs[1].reborn.loadout.abilities[1].rank = 5
local updated = assert(M.save(pool, db, true))
check(M.sameData(M.restore(pool, old), frozen), "older Reborn loadout remains unchanged")
check(
    M.restore(pool, updated).runs[1].reborn.loadout.abilities[1].rank == 5,
    "Reborn loadout edit produces independent version"
)
check(pool.nextRun == 3, "one Reborn run edit creates exactly one new version")
db.settings.rebornResetRunId = "azs:r87654321"
local stateOnly = assert(M.save(pool, db, true))
check(pool.nextRun == 3, "native reset exclusion changes no run version")
local restored = assert(M.restore(pool, stateOnly))
check(
    restored.game == A.game and restored.settings.rebornResetRunId == "azs:r87654321",
    "Reborn game and reset gate restore exactly"
)
check(
    restored.runs[1].nativeRunId == "azs:r12345678"
        and restored.runs[1].recordsReset
        and restored.runs[1].sumResets.kills,
    "native identity and cleanup barriers preserved"
)
check(
    restored.runs[1].reborn.segments[1].damage.displayAmount == 1234,
    "Reborn checkpoint details preserved"
)
check(restored.totals.sum.damage == 987654, "pruned lifetime totals are not rebuilt from runs")
local manual =
    { schema = 2, nextId = 2, entries = { { id = 1, at = 10, runs = 1, data = frozen } } }
local auto = { schema = 2, nextId = 2, entries = { { id = 1, at = 20, runs = 1, data = db } } }
local before = SNAPSHOT({ db, manual, auto })
local staged = assert(M.importLegacy(db, manual, auto))
local persisted = assert(loadstring("return " .. SNAPSHOT(staged)))()
check(
    M.verifyMigration(persisted, db, manual, auto),
    "synthetic Reborn migration parity after Lua serialization"
)
check(
    M.findOrigin(persisted, "manual", 1) ~= M.findOrigin(persisted, "auto", 1),
    "manual and automatic Reborn IDs remain distinct"
)
check(
    SNAPSHOT({ db, manual, auto }) == before,
    "research staging never changes Reborn source tables"
)
restored.runs[1].nativeRunId = "azs:r99999999"
check(
    M.restore(pool, stateOnly).runs[1].nativeRunId == "azs:r12345678",
    "restored Reborn objects never alias pooled data"
)
local foreign = assert(M.restore(pool, old))
foreign.game = nil
check(not M.importLegacy(foreign, manual, auto), "original-game database cannot migrate as Reborn")
print("REBORN-ONLY SHARED STORAGE RESEARCH CONTRACTS PASSED")
