# ConMan+ (Container Manager)

ConMan+ is a Windows utility for browsing and editing the archive ("container") files used by classic 3D games. Open a container, browse its files and folders, and add, delete, rename, move, extract or preview files. Originally written by Alex (see `ConMan.txt` for the original release notes, up to v0.91).

## Features

- Browse containers with a folder tree and file list.
- Create new containers, and add or delete files.
- Rename and move files inside containers. Renaming is not supported for LAB and LFD containers, and moving only works in containers that support subdirectories (Jedi Knight GOB/GOO and PAK).
- Copy/paste and drag & drop to and from Windows Explorer. Dropping a folder onto a container that supports directories keeps its structure.
- Open or double-click a file to extract it and view it in its associated program.
- Extract selected files, or the entire container while keeping its folder structure. The "Extract entire container (keep folders)..." command stays grayed out until a container is open.
- Recent containers list, plus an option to associate container files with ConMan.
- Containers without a recognizable extension are identified by their file header.
- Optional conversion of textures (.MAT) to 16-bit (for Mat16 / NJED / OpenJKDF2) or original 8-bit when extracting from BAF containers.

## Supported containers

| Format | Used by | Support |
|---|---|---|
| GOB (Dark Forces) | Star Wars: Dark Forces | Browse/edit |
| GOB / GOO (with directories) | Jedi Knight, Mysteries of the Sith | Browse/edit |
| LFD | LucasArts games | See source |
| LAB | LucasArts games (e.g. Grim Fandango) | Browse/edit |
| WAD | Doom-style games | See source |
| PAK | Jedi Knight (PAK), Quake-style archives | See source |
| BAF | Star Wars Episode I: Obi-Wan | Read-only |
| CND | Indiana Jones and the Infernal Machine | Read-only |

The exact set of operations available per format depends on the container's structure. Check the source in `u_Containers.pas`, `u_BAF.pas` and `u_CND.pas` for details.

## Building

ConMan is a Delphi VCL application.

- IDE: Embarcadero Delphi 10.4 (Studio 23.0)
- Target: Win32 (Debug or Release)
- Project file: `ConMan.dproj`

Open `ConMan.dproj` in the Delphi IDE and build, or from a RAD Studio command prompt:

```
msbuild ConMan.dproj /p:Config=Release /p:Platform=Win32
```

## Source layout

| File | Purpose |
|---|---|
| `ConMan.dpr` | Program entry point |
| `ContManager.pas/.dfm` | Main window, menus, extraction commands |
| `Files.pas` | Base container and file abstractions |
| `u_Containers.pas` | GOB, LFD, LAB, WAD, GOB2 (JK GOB/GOO), PAK readers and creators |
| `u_BAF.pas` | BAF container support |
| `u_CND.pas` | CND container support |
| `FileOperations.pas`, `DragOut.pas` | Add/delete/copy operations, drag and drop |
| `u_Moveform.pas`, `ProgressDialog.pas`, `AboutCntMan.pas`, `u_options.pas` | Dialogs and options |
| `ConMan.txt` | Original release notes |
| `Conman.hlp` | Original help file |

## Usage

Run `ConMan.exe` and choose **Open Container**, or associate container files with ConMan (Help menu) and double-click them in Explorer. Dropping a container file onto the window asks whether to open it rather than adding it to the current container.

## Credits

Original ConMan by Alex. Updated to build on Delphi 10.4, with added extraction and BAF/CND read-only support.
