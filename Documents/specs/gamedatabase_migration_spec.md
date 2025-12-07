# GameDatabase Migration Spec

## Goal
Migrate all GameDatabase.gd usages to RepositoryFactory pattern, then delete GameDatabase.gd.

## Current State

### Files Using GameDatabase (Active)
| File | Method Used | Migration Target |
|------|-------------|------------------|
| `server_world.gd:229` | `init_database()` | Remove - repos self-init |
| `server_admin_ui.gd:223` | `create_account()` | `AccountJsonRepository.create_account()` |
| `connection_manager.gd:142` | `get_character()` | `CharacterJsonRepository.get_character()` |
| `connection_manager.gd:157` | `save_character()` | `CharacterJsonRepository.save_character()` |

### Existing Repositories
- `account_json_repository.gd` - Has bug in `create_account()` (doesn't save file)
- `character_json_repository.gd` - Complete for basic ops

## Migration Steps

### Step 1: Fix AccountJsonRepository.create_account()
The method creates account_data but doesn't save it.

### Step 2: Add password hashing to RepositoryFactory
GameDatabase has `hash_password()` and `verify_password()` - need equivalent.
Options:
- A) Add to AccountJsonRepository (couples hashing to storage)
- B) Create separate `PasswordService` (cleaner separation)
- C) Add as static methods to RepositoryFactory

**Recommendation:** Option B - `PasswordService` class

### Step 3: Migrate Each File

#### 3a. connection_manager.gd
```gdscript
# Before
var char_result = GameDatabase.get_character(character_id)
GameDatabase.save_character(character_id, character_data)

# After
var char_repo = RepositoryFactory.get_character_repository()
var char_result = char_repo.get_character(character_id)
char_repo.save_character(character_id, character_data)
```

#### 3b. server_admin_ui.gd
```gdscript
# Before
var result = GameDatabase.create_account(username, password)

# After
var password_hash = PasswordService.hash_password(password)
var account_repo = RepositoryFactory.get_account_repository()
var result = account_repo.create_account(username, password_hash)
```

#### 3c. server_world.gd
```gdscript
# Before
GameDatabase.init_database()

# After
# Remove - repositories create directories on first use
```

### Step 4: Delete GameDatabase.gd

### Step 5: Delete backup files
- `apply_auth_fixes.ps1`
- `server_world.gd.admin_version_backup`

## New File Structure
```
source/common/
├── database/
│   ├── repository_factory.gd          # Factory for repos
│   └── repositories/
│       ├── account_json_repository.gd  # Account CRUD
│       └── character_json_repository.gd # Character CRUD
└── services/
    └── password_service.gd             # Password hash/verify
```

## Files Changed Summary
| Action | File |
|--------|------|
| FIX | `account_json_repository.gd` |
| CREATE | `password_service.gd` |
| MODIFY | `connection_manager.gd` |
| MODIFY | `server_admin_ui.gd` |
| MODIFY | `server_world.gd` |
| DELETE | `game_database.gd` |
| DELETE | `apply_auth_fixes.ps1` |
| DELETE | `server_world.gd.admin_version_backup` |

## Risk Mitigation
- Test character save/load after migration
- Test account creation after migration
- Test login flow end-to-end
