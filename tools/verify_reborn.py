"""Contract regressions for the generated, namespaced Reborn runtime (synthetic saves only)."""

from pathlib import Path
import argparse, json, hashlib, sys
from lupa.lua51 import LuaRuntime
from build_reborn import build, ROOT

p = argparse.ArgumentParser()
p.add_argument("--game", type=Path)
args = p.parse_args()
target = build()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((ROOT / "AzerothStats/tests/mock.lua").read_text(encoding="utf8"))
lua.execute(
    """
ORIGINAL={sentinel=true};AzerothStatsDB=ORIGINAL
AzerothStatsBackup={untouched=true};AzerothStatsAutoBackup={untouched=true}
UnitClass=function() return 'Moine','MONK' end
UnitName=function() return 'Tester' end
GetLocale=function() return 'frFR' end
AZS_LOCALE='frFR'
time=function() return 1000 end
IsLoggedIn=function() return true end
GetCVar=function() return '' end
GetSpellInfo=function(id) return 'Test Spell',nil,'Interface\\\\Icons\\\\Spell_Frost_FrostBolt02' end
AZS={handlers={}}
function AZS.On(p,f) AZS.handlers[p]=AZS.handlers[p] or {};table.insert(AZS.handlers[p],f) end
function AZS.ParseKV(msg) local t={};for k,v in string.gmatch(msg or '', '(%w+)=([^;]*)') do t[k]=tonumber(v) or v end;return t end
function AZS.ParseList(msg,names) local out={};for row in string.gmatch(msg or '', '[^;]+') do local v={};local i=1;for s in string.gmatch(row..',','(.-),') do v[names[i] or i]=tonumber(s) or s;i=i+1 end;table.insert(out,v) end;return out end
AZS_List=AZS.ParseList;AZS_Fields=AZS.ParseKV
function ROUTE(p,m) for _,f in ipairs(AZS.handlers[p] or {}) do f(m,p) end end
AZS_ZONE={zone='hellfire',class='monk',dt=3,run='r12345678'}
AZS_RUN={ph='ready',t=0,kills=0,dealt=0,lvl=1};AZS_END={};AZS_SPELLS={};AZS_STATS={};AZS_GEAR={};AZS_REVIVE={};AZS_SCHEDULE={};AZS_UNITS={}
AZS_GetRunTime=function() return AZS_RUN.t end
AZS_L={['Auto Shot']='Tir automatique',['Monk']='Moine',['Hellfire Peninsula']='Péninsule des Flammes infernales'}
"""
)
if args.game:
    native = args.game / "Interface/AddOns"
    for part, name in [
        ("AzerothSurvivors", "Generated/Content.lua"),
        ("AzerothSurvivorsAPI", "Api.lua"),
        ("AzerothSurvivorsAPI", "Meter.lua"),
        ("AzerothSurvivorsAPI", "CombatText.lua"),
    ]:
        lua.execute((native / part / name).read_text(encoding="utf8"))
else:
    lua.execute(
        """
AZS_GEN={classes={{key='monk',name='Monk'},{key='deathknight',name='Death Knight'},{key='demonhunter',name='Demon Hunter'}},zones={{key='hellfire',name='Hellfire Peninsula'}},spells={{key='auto_shot',name='Auto Shot'}}}
AZS_GetPhase=function() return AZS_ZONE.hub~=1 and AZS_RUN.ph or nil end
AZS_GetMeterContext=function(...) assert(select('#',...)==0);return {runId='azs:'..AZS_ZONE.run,uiSessionId='u1',asOfRunSeconds=AZS_RUN.t,languageCode='fr'} end
AZS_GetMeterCapabilities=function(...) assert(select('#',...)==0);return {apiVersion=1,uiSessionId='u1'} end
AZS_GetMeterSnapshot=function(q) assert(type(q)=='table' and q.windowSeconds<=120 and q.runId=='azs:'..AZS_ZONE.run);return {apiVersion=1,totals={recentRate={status='ready',value=100,approximate=true},displayAmount=1000},rows={}} end
AZS_GetMeterLoadout=function(q) return {complete=true,sources={a={abilityKey='auto_shot',name='Auto Shot',spellIds={75}},j={itemKey='test_jewel',name='Test Jewel',rank=4}},abilities={{sourceKey='a',rank=2}},runJewelry={{sourceKey='j',slotId=13}}} end
AZS_GetCombatTextEvents=function() return {apiVersion=1,cursor='ct:1',events={},gap=false} end
AZS_CreateMeterCheckpoint=function(id) assert(type(id)=='string');return {checkpointId='cp:1',runId=id} end
AZS_ReleaseMeterCheckpoint=function(id) assert(type(id)=='string');return true end
AZS_GetUpcomingBosses=function() return {{name='Test Boss',left=30,index=1}} end
AZS_GetGuardians=function() return {{id=1,name='Missing',hp=0,hpm=0},{id=2,name='Present',hp=100,hpm=200,awake=true}} end
"""
    )
for name in (target / "AzerothStatsReborn.toc").read_text().splitlines():
    if name.endswith(".lua"):
        lua.execute((target / name).read_text(encoding="utf8"))
lua.execute(
    """
A=AzerothStatsReborn
TESTS=0
function check(v,msg) TESTS=TESTS+1;assert(v,msg) end
check(AzerothStats==nil,'original namespace untouched')
check(A.InitDB(),'isolated DB initializes')
check(AzerothStatsDB==ORIGINAL and A.db~=ORIGINAL,'original DB unchanged')
check(AzerothStatsBackup.untouched and AzerothStatsAutoBackup.untouched,'original backups unchanged')
check(SlashCmdList.AZEROTHSTATSREBORN and not SlashCmdList.AZEROTHSTATS,'slash command isolated')
check(A.ReadHeroic()==3,'native difficulty')
check(A.RebornStartSegment()==nil,'no checkpoint before a live run')
check(select(2,A.Identity())=='monk','new class')
check(A.knownClasses.deathknight and A.knownClasses.demonhunter,'all twelve classes')
A.DetectLocale();check(A.Locale()=='fr','native locale')
check(A.SourceName('Auto Shot')=='Tir automatique','localized combat sources')
A.Sample();check(not A.run and table.getn(A.db.runs)==0,'ready is not a run')
AZS_RUN.ph='playing';AZS_RUN.t=1;NOW=101;AZS_RUN.ck=2;AZS_RUN.chest=64;AZS_RUN.bk=1;AZS_RUN.gk=3;AZS_RUN.ek=4;AZS_RUN.ge=500
ROUTE('AZSZONE','');ROUTE('AZSRUN','ph=playing;t=1');A.Sample()
check(A.run and A.run.nativeRunId=='azs:r12345678','native identity captured')
check(A.run.game==A.game,'game provenance captured')
check(A.run.values.chests==2 and A.run.values.guardians==3 and A.run.values.bosses==1 and A.run.values.elites==4,'native cumulative counters and cache-price distinction')
check(A.run.reborn.nativeTally.ge==500,'earned gold distinct from spendable balance')
local first=A.run
AZS_RUN.t=10;NOW=110;ROUTE('AZSRUN','ph=playing;t=10');A.Sample()
A.run=nil;A.Sample()
check(A.run==first and not first.resumeHeuristic,'native reload continuity')
AZS_ZONE.run='r87654321';ROUTE('AZSZONE','');A.Sample()
check(A.run~=first and table.getn(A.db.runs)==2,'different UUID never merged')
A.Sample();check(table.getn(A.db.runs)==2,'repeated sample idempotent')
check(A.RebornSnapshot('damage',5)~=nil,'five second window')
check(A.RebornSnapshot('healing',120)~=nil,'120 second healing window')
check(A.RebornSnapshot('damage',4)==nil and A.RebornSnapshot('damage',121)==nil,'window limits')
check(A.RebornSnapshot('received',15)==nil,'unsupported metric rejected')
local cp,err=A.RebornStartSegment();check(cp~=nil,err and err.code or 'checkpoint creates')
check(A.RebornStartSegment()==nil,'one active local segment')
AZS_RUN.t=20;NOW=120;ROUTE('AZSRUN','ph=playing;t=20');A.Sample()
check(A.RebornEndSegment()~=nil,'checkpoint captures and releases')
check(A.RebornEndSegment()==nil,'no duplicate segment release')
local store=A.V2Store(true);store.preferences.combatIntelligence=true
A.V2CombatReset();A.V2CombatTick(A.run)
check(A.V2CombatSnapshot().invalid==0,'native batch accepted without streamId')
local normalized=A.NormalizeCombatBatch({apiVersion=1,cursor='ct:2',gap=true,events={{kind='damage',amount=25,school=4}}})
check(normalized.gap and normalized.events[1].schoolMask==4,'gap and school normalized')
local exported=A.ExportRebornRun(A.run.id);exported.values.damage=999999
check(A.run.values.damage~=999999,'interop detached from live database')
AZS_RUN.endless=1;A.Sample();check(A.run.reborn.endless and table.getn(A.run.reborn.nextBosses)==0,'endless does not invent a future boss')
AZS_ZONE.hub=1;local n=table.getn(A.db.runs);A.Sample();check(table.getn(A.db.runs)==n,'hub does not create run')
AZS_ZONE.hub=nil

local savedFeed=AZS_GetCombatTextEvents
local feedN=0
AZS_GetCombatTextEvents=function(cursor) feedN=feedN+1;return {apiVersion=1,cursor='probe:'..feedN,gap=true,events={{kind='damage',amount=125,school=4,critical=true,periodic=true,meterSource='Auto Shot'},{kind='heal',amount=25}}} end
A.V2CombatReset();A.V2CombatTick(A.run)
local sum=A.V2CombatSnapshot()
check(sum.hits==1 and sum.damageObserved==125 and sum.critical==1 and sum.periodic==1,'structured damage classification')
check(sum.invalid==0 and sum.gaps==1,'heals are not malformed damage and gaps are retained')
check(sum.schools['4'].damage==125,'native school retained')
AZS_GetCombatTextEvents=savedFeed
check(A.RebornSection('Reborn:60')=='Reborn' and A.rebornWindow==60,'window UI choice wired')

UnitGUID=function() return 'player:1' end
local deathFrame=getglobal('AzerothStatsRebornDeathLog')
deathFrame.scripts.OnEvent(deathFrame,'COMBAT_LOG_EVENT_UNFILTERED',NOW,'SPELL_DAMAGE','enemy:1','Native Boss',0,'player:1','Tester',0,123,'Fatal spell',4,300,25,4,0,0,0,false)
A.MarkDeath()
check(A.run.reborn.fatal and A.run.reborn.fatal.overkill==25,'native fatal hit recorded')
check(A.run.deaths[1].confidence=='confirmed','structured fatal evidence confirms attribution')

AZS_END={result='dead',quit=0,t=20}
check(A.ReadSummary().result=='defeat' and AZS_END.result=='dead','native death summary normalized without modifying native data')
AZS_END.quit=1;check(A.ReadSummary().result=='left','native quit normalized as abandonment')
AZS_END.hero={};check(A.ReadSummary()==nil,'normalization never launders malformed identity fields')
local before=A.db.totals.runs


AZS_END={result='victory',t=20,dmg=1000,hero='Tester',zone='hellfire',class='monk'}
A.Packet('AZSEND','result=victory');A.Sample()
local total=A.db.totals.runs
A.Sample();A.Sample()
check(A.db.totals.runs==total and A.run.result=='victory','terminal summary counted once')
local match=A.SummaryMatches(A.run,{runId='azs:r00000000',hero='Tester',zone='hellfire'})
check(not match,'foreign native summary rejected')
A.view.rebornMode='campaign';check(not A.MatchesHistory(A.run),'campaign filter excludes endless continuation')
A.view.rebornMode='all'

check(A.ValidateDatabase(A.db),'enriched database validates')
local foreign=A.Copy(A.db);foreign.game=nil;check(not A.ValidateDatabase(foreign),'original-game saves cannot be restored into Reborn')
check(A.CreateDataBackup(),'namespaced backup stores enriched Reborn data')
check(AzerothStatsBackup.untouched and AzerothStatsRebornBackup.entries[1].data.game==A.game,'backup roots stay isolated')
local getSnapshot=AZS_GetMeterSnapshot;AZS_GetMeterSnapshot=nil
local missing,why=A.RebornSnapshot('damage',15)
check(not missing and why.code=='API_MISSING','unavailable API is not fabricated zero')
AZS_GetMeterSnapshot=getSnapshot
local series=A.V2Curve({reborn={windowSamples={{t=15,damage=20},{t=30,healing=50},{t=45,damage=30}}}},'recentDps')
check(table.getn(series)==2 and series[2].value==30 and series[2].gap,'DPS curve never uses healing as missing damage and shows gaps')


"""
)
if not args.game:
    lua.execute(
        """
check(A.run.reborn.loadout.jewelry[1].rank==4,'jewelry rank retained')
check(table.getn(A.run.reborn.guardians)==1,'no empty guardian observations')
for _,theme in ipairs(A.themeOrder) do
 A.UseTheme(theme);local model={rows={}};A.view.reportSection='Reborn';A.ReportModel(model,A.run)
 check(A.activeTheme==theme and table.getn(model.rows)>=6,'Reborn report works with each actual theme')
end
"""
    )
lua.execute((ROOT / "AzerothStats/tests/serialize.lua").read_text(encoding="utf8"))
lua.execute(
    "local saved=SNAPSHOT(A.db);AzerothStatsRebornDB=assert(loadstring('return '..saved))();A.run=nil;check(A.InitDB() and A.ValidateDatabase(A.db),'Reborn save serialization roundtrip')"
)
lua.execute(
    "A.BuildUI();for _,theme in ipairs(A.themeOrder) do A.UseTheme(theme);A.ApplyUI();A.RefreshUI();check(A.window~=nil,'all five themes build actual UI widgets') end"
)
for path in target.glob("*.lua"):

    raw = path.read_text(encoding="utf8")
    lua.eval("function(s) local f,e=loadstring(s);assert(f,e) end")(raw)
    assert "Interface\\\\AddOns\\\\AzerothStats\\\\" not in raw, path
    assert "AzerothStatsDB" not in raw, path
print(
    "PASS:",
    lua.globals().TESTS,
    (
        "Reborn checks; installed API"
        if args.game
        else "Reborn checks; synthetic native contract"
    ),
)
(ROOT / "build/reborn-validation.json").write_text(
    json.dumps(
        {
            "checks": lua.globals().TESTS,
            "installedAPI": bool(args.game),
            "scope": "Lua 5.1, generated runtime, synthetic saves/host; not in-game visual acceptance",
        },
        indent=2,
    )
    + "\n"
)
