# Refactoring Specification: Gateway & Database

## 1. Overview
This document outlines the plan to refactor `gateway.gd` and `game_database.gd` to eliminate "God Class" anti-patterns, improve testability, and prepare the codebase for beta testing.

## 2. Architecture Changes

### A. Client Architecture (`source/client/`)
The monolithic `gateway.gd` will be split into:
1.  **`GatewayUIManager`** (`source/client/gateway/gateway_ui_manager.gd`):
    *   **Role**: View Controller.
    *   **Responsibilities**: Handle button signals, show/hide panels (`LoginPanel`, `DevTools`), manage UI state.
    *   **Dependencies**: `AuthenticationService`, `SceneNavigationService`, `DeveloperToolsService`.
2.  **`SceneNavigationService`** (`source/client/autoload/scene_navigation.gd`):
    *   **Role**: Router.
    *   **Responsibilities**: Centralize `change_scene_to_file` calls.
    *   **Methods**: `goto_login()`, `goto_world(id)`, `goto_character_creation()`.
3.  **`DeveloperToolsService`** (`source/client/tools/developer_tools_service.gd`):
    *   **Role**: Tooling.
    *   **Responsibilities**: Launch external apps (Tiled, Pixi), run deployment scripts.
    *   **Methods**: `launch_tiled()`, `push_to_remote()`.

### B. Common Architecture (`source/common/`)
The monolithic `game_database.gd` will be split into a Repository Pattern:
1.  **`AuthenticationService`** (`source/common/services/authentication_service.gd`):
    *   **Role**: Domain Service.
    *   **Responsibilities**: Handle login logic, password hashing, session tokens.
    *   **Dependencies**: `AccountRepository`.
2.  **`RepositoryFactory`** (`source/common/database/repository_factory.gd`):
    *   **Role**: Factory.
    *   **Responsibilities**: Return the correct repository implementation (JSON vs SQL) based on config.
3.  **Repositories** (`source/common/database/repositories/`):
    *   **`AccountRepository`**: Interface for account CRUD.
    *   **`CharacterRepository`**: Interface for character CRUD.
    *   **Implementations**: `AccountJsonRepository`, `AccountSqlRepository`, etc.

## 3. Implementation Plan

### Phase 1: Database Refactor (The Foundation)
1.  Create `source/common/database/repositories/`.
2.  Extract JSON logic from `game_database.gd` into `account_json_repository.gd` and `character_json_repository.gd`.
3.  Create `repository_factory.gd` to manage access.
4.  Create `authentication_service.gd` to handle the business logic (hashing, validation).
5.  Update `server_world.gd` and other server-side scripts to use the new Factory and Service instead of `GameDatabase` static calls.

### Phase 2: Gateway Refactor (The UI)
1.  Create `source/common/network/services/auth_network_service.gd` (if not fully utilized) or ensure `AuthenticationService` handles the client-side network requests.
2.  Create `developer_tools_service.gd` and move the "Launch Tiled/Deploy" logic there.
3.  Create `scene_navigation.gd` autoload.
4.  Refactor `gateway.gd` into `gateway_ui_manager.gd`, stripping out all logic and leaving only UI event handling that delegates to the new services.

### Phase 3: Verification
1.  **Unit Test**: Test the `AccountJsonRepository` in isolation.
2.  **Integration Test**: Verify Login flow using the new `AuthenticationService`.
3.  **Manual Test**: Click through the Gateway UI to ensure all buttons still work.

## 4. Git & Safety
*   Changes will be committed in atomic steps (e.g., "Refactor: Extract AccountRepository").
*   `game_database.gd` will be kept (deprecated) until all references are migrated.
