#!/usr/bin/env node

/**
 * Claude Hook: Block git commit attempts
 *
 * Prevents Claude from running `git commit` directly.
 * Forces proper workflow: create .commit-msg and tell developer to run `make commit`
 *
 * Usage: Configure in Claude Code settings under hooks.PreToolUse for Bash tool
 */

const readline = require('readline');

async function readStdin() {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    terminal: false
  });

  let data = '';
  for await (const line of rl) {
    data += line;
  }

  return data ? JSON.parse(data) : null;
}

async function main() {
  try {
    const input = await readStdin();

    // Only process Bash tool calls
    if (!input || input.tool_name !== 'Bash') {
      process.exit(0);
    }

    // Check if command contains 'git commit'
    const command = input.tool_input?.command || '';
    if (!command.includes('git commit')) {
      process.exit(0);
    }

    // Block git commit with helpful message
    const message = `
You must create .commit-msg via wdone workflow and 
tell the developer to run 'make commit'

Claude cannot commit directly. This enforces the workflow:
1. Complete work and create .commit-msg (via wdone)
2. Tell developer: "Run 'make commit'"
3. Developer executes the commit
\n`;

    process.stderr.write(message);
    process.exit(2);
  } catch (error) {
    // On any error, allow the tool (safe default)
    process.exit(0);
  }
}

main();
