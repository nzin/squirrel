# Squirrel Game

A scrolling pygame game featuring a squirrel character.

## Installation

Install dependencies using Poetry:

```bash
poetry install
```

## Running the Game

### Local Development

Activate the Poetry environment and run:

```bash
poetry run python -m squirrel.main
```

Or activate the shell first:

```bash
poetry shell
python -m squirrel.main
```

### Web Build (pygbag)

To run the game in a web browser using pygbag:

```bash
poetry run python -m pygbag --ume_block 0 squirrel/main.py
```

## Controls

- **SPACE** - Jump
- **SHIFT** - Throw acorn
- **Close window** - Quit game

## Features

- Continuous scrolling background with soil
- Squirrel character with jumping mechanics
- Acorn throwing system (starts with 3 acorns)
- Real-time acorn counter display
- Score system
- Multiple enemy types (skunks, birds, crocos, pterodactyls)
- Collectible boxes and rainbow acorns
- Cloud platforms
- Game over menu with restart option

