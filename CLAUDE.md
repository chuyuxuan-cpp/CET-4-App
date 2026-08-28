# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project: CET-4 App

CET-4 vocabulary learning application.

## Auto Git Push

After every code-writing task, stage all changes, commit with a descriptive message, and push to GitHub. The project is public at `https://github.com/chuyuxuan-cpp/CET-4-App`.

## Sound Notification

Every task completion triggers a system notification sound.

## Disk Space Constraint

C drive space is precious. Never install SDKs, emulators, caches, or dependencies on C:. All dev tooling lives on D: (Flutter SDK, Android SDK at `D:\Android\Sdk`, AVDs at `D:\Android\avd`, Gradle at `D:\Dev\gradle`, Pub cache at `D:\Dev\pub-cache`) and the project itself is on E:. User-level env vars are already configured; keep them intact.
