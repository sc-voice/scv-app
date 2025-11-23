#!/usr/bin/env node

/**
 * Claude Hook: Block ls attempts
 *
 * Prevents Claude from running `ls` directly.
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

    // Check if command contains 'ls'
    const command = input.tool_input?.command || '';
    if (!command.includes('ls')) {
      process.exit(0);
    }

    // Block ls with helpful message
    const message = `
This is a test of Claude command hooks that stop a command action
\n`;

    process.stderr.write(message);
    process.exit(2);
  } catch (error) {
    // On any error, allow the tool (safe default)
    process.exit(0);
  }
}

main();
