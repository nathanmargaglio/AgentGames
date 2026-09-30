#!/usr/bin/env python3
"""Connect through stdio and exercise the actual project MCP server."""
import asyncio,json,pathlib
from mcp import ClientSession,StdioServerParameters
from mcp.client.stdio import stdio_client
ROOT=pathlib.Path(__file__).resolve().parents[1]
async def main():
 params=StdioServerParameters(command='uv',args=['run','python','tools/mcp_server.py'],cwd=str(ROOT))
 async with stdio_client(params) as (r,w):
  async with ClientSession(r,w) as session:
   await session.initialize();listing=await session.list_tools()
   assert {t.name for t in listing.tools}=={'list_games','build_game','validate_project','test_games','inspect_toolchain'}
   result=await session.call_tool('list_games');assert not result.isError
   result=await session.call_tool('build_game',{'game':'debug'});assert not result.isError
   payload=json.loads(result.content[0].text);assert payload['ok'],payload
   result=await session.call_tool('validate_project');assert not result.isError
   payload=json.loads(result.content[0].text);assert payload['ok'],payload
   resources=await session.list_resources();assert any(str(x.uri)=='agentgames://workflow' for x in resources.resources)
   print('MCP stdio checks: PASS (initialize, tools, metadata, validation, workflow resource).')
if __name__=='__main__':asyncio.run(main())
