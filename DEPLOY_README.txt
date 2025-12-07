================================================================================
                    ODYSSEYS REVIVAL - DEPLOYMENT SCRIPTS
================================================================================

QUICK START
-----------
Use the in-game buttons from Gateway menu, OR double-click these scripts:

  deploy_client_production.bat  - Build & upload PLAYER client
  deploy_client_dev.bat         - Build & upload DEV client (debug tools)
  deploy_to_remote.bat          - Push server code to remote
  deploy_client_pipeline.bat    - Full pipeline (all clients + server)


VERSION SYSTEM
--------------
All versions must stay in sync:

  version.txt      <- MASTER (edit this to change version)
  project.godot    <- Auto-synced from version.txt during deploy
  R2 version.json  <- Created during deploy, matches version.txt

The deploy scripts will:
  1. Check if version.txt and project.godot match
  2. Auto-fix any mismatch (project.godot syncs to version.txt)
  3. Ask if you want to increment version (Y/N)
  4. Show confirmation of what will be deployed
  5. Ask to proceed (Y/N)
  6. Build, package, and upload


CLIENT vs SERVER VERSIONS
-------------------------
- Production client uses: version.json in /channels/production/
- Dev client uses:        version.json in /channels/dev/ (version + "-dev")
- Client checks server version on startup via game_updater.gd


FILES UPDATED DURING DEPLOY
---------------------------
Production Client Deploy:
  LOCAL:   version.txt, project.godot
  R2:      /channels/production/version.json
           /channels/production/game.pck
           /installers/OdysseyRevival.zip

Dev Client Deploy:
  LOCAL:   version.txt, project.godot
  R2:      /channels/dev/version.json
           /channels/dev/game.pck
           /installers/OdysseyDevClient.zip


DOWNLOAD URLS
-------------
Player:  https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/installers/OdysseyRevival.zip
Dev:     https://pub-bfb251fbb7f04473b6eb939aba7ccdfc.r2.dev/installers/OdysseyDevClient.zip


TROUBLESHOOTING
---------------
- "Godot not found" - Install Godot 4.5 to C:\Godot\
- "rclone not found" - Run setup_rclone.bat first
- "export_presets.cfg not found" - Open Godot > Project > Export, configure presets
- Build fails - Check Godot output for errors


================================================================================
