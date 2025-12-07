# Specification: GitHub Actions CI/CD for Client Builds & R2 Deployment

## 1. Objective
Automate the process of building game clients (Development and Production) and deploying them to Cloudflare R2 using GitHub Actions. This will eliminate manual intervention, reduce errors, and bypass local machine setup issues.

## 2. Problem Analysis
*   **Current State:** Client builds and uploads are performed manually via local `.bat` scripts (`deploy_client_dev.bat`, `deploy_client_production.bat`) that utilize `rclone`.
*   **Failure Point:** Manual processes are time-consuming, inconsistent, and rely on the local developer machine's environment, which can introduce errors or be affected by local issues (though the `rclone` issue is primarily with server updates, local client builds can also have environment-specific problems).
*   **Requirement:** A fully automated and reliable system for building and deploying clients upon code changes.

## 3. Proposed Architecture: GitHub Actions CI/CD

### 3.1. Data Flow
1.  **Developer:** Commits and pushes changes to the `main` branch of the GitHub repository (`git push`).
2.  **GitHub Actions:** Automatically detects the push event to the `main` branch.
3.  **Build Job:** Initiates a job to build the Godot game client for specified platforms (e.g., Windows x64).
4.  **Deployment Job:**
    *   Authenticates with Cloudflare R2 using securely stored GitHub Secrets.
    *   Uploads the built client artifacts (e.g., zipped `game.pck` and executable) to the appropriate R2 buckets/paths (e.g., `/channels/production/` and `/channels/dev/`).
    *   Optionally updates a `version.json` file in R2 to reflect the new client version.

### 3.2. Components

#### A. GitHub Actions Workflow File
*   **File:** `.github/workflows/client_ci_cd.yml`
*   **Triggers:** `on: [push]` to the `main` branch.
*   **Jobs:**
    *   `build_windows_client`:
        *   Sets up Godot environment (e.g., `Godot-actions/setup-godot@v1`).
        *   Uses Godot command-line export to build the client (e.g., `godot --export-release "Windows Desktop"`).
        *   Compresses the exported client into a `.zip` archive.
        *   Uploads the archive as a GitHub Action artifact.
    *   `deploy_r2`:
        *   Downloads the build artifacts.
        *   Configures `rclone` or Cloudflare `wrangler` CLI for R2 access.
        *   Uploads the client `.zip` to the designated R2 path.
        *   Uploads a generated `version.json` to R2 (based on `version.txt`).

#### B. Cloudflare R2 Credentials (GitHub Secrets)
*   `CLOUDFLARE_ACCOUNT_ID`
*   `CLOUDFLARE_R2_ACCESS_KEY_ID`
*   `CLOUDFLARE_R2_SECRET_ACCESS_KEY`

#### C. Godot Export Presets
*   Ensure `export_presets.cfg` is correctly configured in the repository for "Windows Desktop" (or other target platforms).

#### D. Versioning (Optional but Recommended)
*   The `version.txt` file (already exists) can be read by the CI/CD pipeline to generate a `version.json` that gets uploaded to R2. This allows clients to check for updates.

## 4. Implementation Plan

### Phase 1: Workflow Setup
1.  **Create Workflow File:** Create `.github/workflows/client_ci_cd.yml`.
2.  **Define Build Job:** Add the job to build for Windows x64, using a specific Godot version.
3.  **Define Deploy Job:** Add the job to upload to R2 using `rclone` (or `wrangler` if more appropriate for R2).

### Phase 2: Configuration
1.  **GitHub Secrets:** Instruct the user to add the Cloudflare R2 credentials as GitHub Secrets.
2.  **R2 Bucket Structure:** Confirm or establish the desired R2 bucket names and folder structure (e.g., `your-bucket/channels/production/`, `your-bucket/channels/dev/`).

### Phase 3: Testing & Refinement
1.  **Trigger Workflow:** Push a small change to `main` to trigger the workflow.
2.  **Verify Builds:** Check GitHub Actions logs for successful builds.
3.  **Verify Deployment:** Check R2 bucket for uploaded files.
4.  **Client Update Logic:** Review `game_updater.gd` (from `DEPLOY_README.txt` mentioning client checks) to ensure it correctly pulls from the R2 paths.

## 5. Security Considerations
*   Cloudflare R2 credentials **must** be stored as GitHub Secrets and never hardcoded in the workflow file.
*   Limit access permissions for the R2 credentials to only what's necessary (e.g., write to specific buckets).
