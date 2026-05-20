# Video 2 (REAL) — captured live Claude tutor session
#
# Render with:
#   bin/capture-real-tutor.sh       # writes/refreshes video2-real.dialog
#   vhs docs/demo/scenarios/video2-real.tape
#
# Output: docs/demo/scenarios/video2-real.mp4
#
# Unlike video2.tape (scripted), this one plays back a transcript captured
# from a real `claude -p` session against the course wiki. Re-running the
# capture produces a different transcript — keep one you like.

Output docs/demo/scenarios/video2-real.mp4

Set Shell "bash"
Set FontSize 28
Set Width 1920
Set Height 1080
Set Padding 20
Set Theme "Dracula"
Set TypingSpeed 0ms
Set PlaybackSpeed 1.0
Set FontFamily "Menlo, Monaco, monospace"

Hide
Type "cd /Users/csweet1/Documents/projects/TCF/microelectronics-tutor-demo"
Enter
Sleep 200ms
Type "clear"
Enter
Sleep 200ms
Show

# Captured live with a human-in-the-loop student (2026-05-17, third take).
# 11 tutor turns + 7 inline wiki URL references + closing scene. With the
# inline-URL behavior (vs the older full-screen glow render) the recording
# is ~2:40 instead of 3:35; Sleep 180s is the tight upper bound.
Type "./docs/demo/scenarios/lib/play-dialog.sh docs/demo/scenarios/video2-real.dialog"
Enter
Sleep 195s
