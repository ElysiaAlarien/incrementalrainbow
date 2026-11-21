# Godot 4 as the engine

The game must ship on iOS, Android, and Steam (Windows, macOS, and Linux) from one codebase. We chose Godot 4 because it exports to all of these targets, is strong for 2D, and has no license or runtime fees. We rejected Unity because of licensing risk, and a web stack (TypeScript in Capacitor and Electron) because of large desktop builds and weaker native integration on Steam.
