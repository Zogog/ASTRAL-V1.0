from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'src'
OUT = ROOT / 'dist' / 'ASTRAL.lua'
order = [
    'core/State.lua','core/Config.lua','core/Runtime.lua','core/Scheduler.lua','core/GameAPI.lua','core/ModuleManager.lua',
    'modules/Stubs.lua','ui/Window.lua'
]

def bracket(s):
    for n in range(1,10):
        eq='='*n
        close=']'+eq+']'
        if close not in s:
            return '['+eq+'['+s+']'+eq+']'
    raise RuntimeError('unable to quote source')

parts=[]
for rel in order:
    parts.append(f'    [{rel!r}] = {bracket((SRC/rel).read_text(encoding="utf-8"))},')

bundle = '''--[[\n ASTRAL 1.0.0-dev.1 — Foundation\n Generated bundle. Edit src/, then run tools/build.py.\n No gameplay automation or Adopt Me remotes are included in this release.\n]]\n\nlocal ASTRAL = {\n    Name = "ASTRAL",\n    Version = "1.0.0-dev.1",\n    Build = "Foundation",\n}\n\nif getgenv then\n    local env = getgenv()\n    if env.ASTRAL and env.ASTRAL.Runtime and env.ASTRAL.Runtime.Destroy then\n        pcall(function() env.ASTRAL.Runtime:Destroy() end)\n    end\n    env.ASTRAL = ASTRAL\nend\n\nlocal SOURCES = {\n''' + '\n'.join(parts) + '''\n}\n\nlocal function run(path)\n    local src = assert(SOURCES[path], "Missing bundled module: " .. path)\n    local fn, err = loadstring(src, "@ASTRAL/" .. path)\n    assert(fn, err)\n    local factory = fn()\n    assert(type(factory) == "function", "Invalid module factory: " .. path)\n    return factory(ASTRAL)\nend\n\nrun("core/State.lua")\nrun("core/Config.lua")\nrun("core/Runtime.lua")\nrun("core/Scheduler.lua")\nrun("core/GameAPI.lua")\nrun("core/ModuleManager.lua")\nrun("modules/Stubs.lua")\nrun("ui/Window.lua")\n\nASTRAL.State.Runtime = "READY"\nASTRAL.State:Log("ASTRAL " .. ASTRAL.Version .. " foundation loaded")\nASTRAL.State:Log("Gameplay modules are intentionally empty in dev.1")\nif ASTRAL.UI then ASTRAL.UI:Refresh() end\nreturn ASTRAL\n'''
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(bundle, encoding='utf-8')
print(f'Built {OUT} ({OUT.stat().st_size:,} bytes)')
