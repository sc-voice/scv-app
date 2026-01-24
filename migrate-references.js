#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { v4: uuidv4 } = require('crypto').randomUUID ? (() => ({ v4: () => require('crypto').randomUUID() })) : require('uuid');

const TASKS_DIR = path.join(__dirname, 'Tasks');

function extractURL(text) {
  const urlMatch = text.match(/(https?:\/\/[^\s]+)$/);
  if (urlMatch) {
    const url = urlMatch[1];
    const cleanText = text.slice(0, urlMatch.index).trim();
    return {
      text: cleanText || url,
      url: url
    };
  }
  return null;
}

function migrateReference(oldRef) {
  const { randomUUID } = require('crypto');
  const id = randomUUID();

  if (oldRef.filePath) {
    return {
      id,
      text: oldRef.filePath,
      url: null,
      relevance: 0.5
    };
  }

  if (oldRef.text) {
    const extracted = extractURL(oldRef.text);
    if (extracted) {
      return {
        id,
        text: extracted.text,
        url: extracted.url,
        relevance: 0.75
      };
    }
    return {
      id,
      text: oldRef.text,
      url: null,
      relevance: 0.5
    };
  }

  return {
    id,
    text: null,
    url: null,
    relevance: 0.5
  };
}

function migrateTaskFile(filepath) {
  try {
    const content = fs.readFileSync(filepath, 'utf8');
    const task = JSON.parse(content);

    if (task.references && Array.isArray(task.references)) {
      task.references = task.references.map(ref => migrateReference(ref));

      fs.writeFileSync(
        filepath,
        JSON.stringify(task, null, 2) + '\n',
        'utf8'
      );

      console.log(`✓ Migrated: ${path.basename(filepath)}`);
      return true;
    }
  } catch (error) {
    console.error(`✗ Error migrating ${path.basename(filepath)}: ${error.message}`);
    return false;
  }
}

function main() {
  try {
    const files = fs.readdirSync(TASKS_DIR);
    const jsonFiles = files.filter(f => f.endsWith('.json'));

    console.log(`Migrating ${jsonFiles.length} task files...\n`);

    let migrated = 0;
    for (const filename of jsonFiles) {
      const filepath = path.join(TASKS_DIR, filename);
      if (migrateTaskFile(filepath)) {
        migrated++;
      }
    }

    console.log(`\nMigration complete! ${migrated}/${jsonFiles.length} files migrated.`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exit(1);
  }
}

main();
