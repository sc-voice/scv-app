# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Communication Style

- Be direct and terse
- Use neutral affect
- Use hypotheses and avoid assertions
- Assertions can be used with source code line references
- Assertions can be used with url references

## Project Overview

SC-Voice is a localizable set of Swift applications for searching and viewing 
Buddhist suttas (scriptures).  It uses SwiftData for persistence 
and provides a card-based interface where users can create multiple search and sutta viewer cards.

## Permissions

- you can read any file in project except those in secret/

## Workflow

Work is organized into "work sessions" that end with a git commit.

Each work session must start with:

- a single Objective 
- a Plan to meet that objective 
- a Test to verify that objective has been met

Once the entire Test passes, developer approval is required for git commit

