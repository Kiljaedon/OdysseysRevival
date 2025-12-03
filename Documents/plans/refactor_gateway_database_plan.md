# Refactoring Plan: Gateway & Database

## Phase 1: Database & Service Layer
*   [ ] **Create Directory Structure**: `source/common/database/repositories/`, `source/common/services/`.
*   [ ] **Create Account Repository**:
    *   Extract JSON account logic from `game_database.gd` to `source/common/database/repositories/account_json_repository.gd`.
    *   Define implicit interface (duck-typing) for `get_account`, `create_account`, `update_account`.
*   [ ] **Create Character Repository**:
    *   Extract JSON character logic to `source/common/database/repositories/character_json_repository.gd`.
*   [ ] **Create Repository Factory**:
    *   Implement `source/common/database/repository_factory.gd`.
    *   Add logic to choose between JSON (default) and SQL (placeholder).
*   [ ] **Create Authentication Service**:
    *   Implement `source/common/services/authentication_service.gd`.
    *   Move `hash_password`, `validate_password`, `validate_username` from `game_database.gd` and `CredentialsUtils`.
*   [ ] **Verify**: Create a test script `tests/test_database_refactor.gd` to CRUD an account using the new system.

## Phase 2: Client Services
*   [ ] **Create Scene Navigation**: `source/client/autoload/scene_navigation.gd`.
*   [ ] **Create Developer Tools Service**: `source/client/tools/developer_tools_service.gd`.
    *   Move Tiled/Pixi launching logic here.
    *   Move `deploy_to_remote.bat` generation here.

## Phase 3: Gateway Decomposition
*   [ ] **Refactor `gateway.gd`**:
    *   Rename to `gateway_ui_manager.gd` (or keep name but change logic).
    *   Inject/Autoload dependencies: `SceneNavigation`, `DeveloperToolsService`, `AuthService`.
    *   Replace complex logic with service calls (e.g., `DevTools.launch_tiled()`).
*   [ ] **Verify**: Run the client and check Login, Dev Tools menu, and Scene transitions.

## Phase 4: Server Integration
*   [ ] **Update Server World**:
    *   Replace `GameDatabase` calls in `server_world.gd` (and managers) with `RepositoryFactory.get_account_repo()`.
*   [ ] **Cleanup**:
    *   Mark `game_database.gd` as deprecated or remove it if fully migrated.
