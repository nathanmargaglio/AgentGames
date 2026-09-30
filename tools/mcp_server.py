#!/usr/bin/env python3
"""Project-scoped stdio MCP bridge for the reproducible headless pipeline."""
import json,subprocess
from mcp.server.fastmcp import FastMCP
from common import ROOT,game_dir,read,games,godot,blender
mcp=FastMCP('AgentGames')

def command(args):
 result=subprocess.run(args,cwd=ROOT,capture_output=True,text=True,timeout=300)
 return {'ok':result.returncode==0,'output':(result.stdout+result.stderr)[-16000:]}

@mcp.tool()
def list_games() -> dict:
 """List game metadata, versions, and committed build stamps."""
 return {'version':(ROOT/'VERSION').read_text().strip(),'games':[{'metadata':read(p),'build':read(p.parent/'build.json') if (p.parent/'build.json').exists() else None} for p in games()]}

@mcp.tool()
def build_game(game: str, regenerate_blender_assets: bool=False) -> dict:
 """Export a changed game to the browser locally; optionally regenerate Blender art. No paid API calls."""
 game_dir(game)
 args=['python3','tools/build.py','--game',game]
 if regenerate_blender_assets:args.append('--assets')
 return command(args)

@mcp.tool()
def validate_project() -> dict:
 """Check version histories, portal catalog, source fingerprints, and all built file hashes."""
 return command(['python3','tools/validate.py'])

@mcp.tool()
def test_games() -> dict:
 """Run headless Godot gameplay checks and pipeline checks."""
 return command(['python3','tools/test.py'])

@mcp.tool()
def inspect_toolchain() -> dict:
 """Report installed engine and asset authoring versions."""
 return {'godot':command([godot(),'--version']),'blender':command([blender(),'--version'])}

@mcp.resource('agentgames://workflow')
def workflow() -> str:
 return (ROOT/'AGENTS.md').read_text()

if __name__=='__main__':mcp.run(transport='stdio')
