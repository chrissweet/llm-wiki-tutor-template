# Video 1 — The Shortcut
#
# Render with:
#   cd <repo root>
#   vhs docs/demo/scenarios/video1.tape
#
# Output: docs/demo/scenarios/video1.mp4 (~90 seconds)

Output docs/demo/scenarios/video1.mp4

Set Shell "bash"
Set FontSize 28
Set Width 1920
Set Height 1080
Set Padding 20
Set Theme "Dracula"
Set TypingSpeed 0ms
Set PlaybackSpeed 1.0
Set FontFamily "Menlo, Monaco, monospace"

# Boot — silent setup, then clear.
Hide
Type "cd /Users/csweet1/Documents/projects/TCF/microelectronics-tutor-demo"
Enter
Sleep 200ms
Type "clear"
Enter
Sleep 200ms
Show

# Play the dialog. Sleep must exceed the dialog's natural runtime — the
# player script blocks on its own internal sleeps, so VHS just records.
# Measured runtime: ~44s with default delays; 55s gives ~10s buffer at end.
Type "./docs/demo/scenarios/lib/play-dialog.sh docs/demo/scenarios/video1.dialog"
Enter
Sleep 55s
