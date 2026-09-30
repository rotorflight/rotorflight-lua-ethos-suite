# Bastion theme name

The theme previously called Aegis is now **Bastion**. The September 30, 2026
rename changes the GitHub branch, dashboard headings, monitoring label, theme
selection/configuration labels, and Theme Bridge palette name.

The dedicated branch is `radio-theme-bastion`; the same branding is included in
`radio-all-themes`. The graphite/cyan shield design and telemetry behavior are
preserved.

Existing radio selections and thresholds continue to use `system/aegis`,
`dashboard.aegis`, and `widgets/dashboard/themes/aegis`. These are compatibility
identifiers, not the display name. Keep the folder named `aegis` when copying an
update so saved theme selections and settings still resolve correctly.

The theme overlay under `artifacts/theme-refresh` includes the renamed theme
content. The full branch source also updates the two app picker labels and the
Bridge fallback palette name. Desktop previews are generated from the actual
Lua modules using simulated telemetry and approximate radio fonts.
