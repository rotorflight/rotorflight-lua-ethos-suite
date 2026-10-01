# Bastion theme name

The theme previously called Aegis is now **Bastion**. The September 30, 2026
rename changes the GitHub branch, dashboard headings, monitoring label, theme
selection/configuration labels, and Theme Bridge palette name.

The dedicated branch is `radio-theme-bastion`; the same branding is included in
`radio-all-themes`. The graphite/cyan shield design and telemetry behavior are
preserved.

As of October 1, 2026, the source folder is
`src/rfsuite/widgets/dashboard/themes/bastion`. The branch routes the legacy
theme selection `system/aegis` to this folder. The internal theme ID remains
`aegis`, and saved instrument thresholds remain in the `dashboard.aegis` section
of the radio's `SCRIPTS:/rfsuite.user/settings.ini`. Existing selections and
thresholds therefore continue to work without a settings migration.

Install the complete, matching Suite files from `radio-theme-bastion` or
`radio-all-themes`, then restart the scripts or radio. The updated dashboard,
settings page, and optional Theme Bridge routing must accompany the `bastion`
folder; copying the folder alone onto an older Suite installation is not enough.
Keep the radio's existing user settings when updating.

The September 7 ZIP and manifest under `artifacts/theme-refresh` are archived
artifacts with the earlier `aegis` folder layout. Use the current branch for a
current installation. Historical desktop previews use simulated telemetry and
approximate radio fonts; the folder rename does not change the theme's visuals.
