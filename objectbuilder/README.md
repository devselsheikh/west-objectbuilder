# Object Builder (by West)

Standalone FiveM runtime object placement resource with secure server validation and ACE permission control.

## Permissions

Grant access with ACE:

```cfg
add_ace group.admin objectbuilder.use allow
add_ace group.admin objectbuilder.admin allow
```

## Usage

1. Ensure resource in `server.cfg`: `ensure objectbuilder`
2. Use `/objectbuilder` in-game.
3. Select model and start preview.
4. Place with `Enter`.

## Security

- Server-side model whitelist
- Per-player placement rate limiting + abuse lock
- Distance and coordinate validation
- Payload size cap for map operations
- Silent rejection for malformed requests

## Data

Maps are stored under `maps/<name>.json` in the resource folder.
