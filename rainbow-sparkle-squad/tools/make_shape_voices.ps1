# Render the spoken shape clips with the built-in Windows voice (SAPI).
#
#   powershell -File tools/make_shape_voices.ps1
#
# Output, into assets/audio/, mono 22050 Hz 16-bit PCM:
#   shape_<name>.wav   "Circle!"            - said when a shape is touched
#   find_<name>.wav    "Find the circle!"   - the round's instruction
#   say_wellDone.wav / say_tryAgain.wav     - praise and encouragement
#
# The instruction clips are the load-bearing ones. Shape Cove is for a player
# who cannot read the prompt on screen, so the round has to be spoken or the
# game is unplayable. The on-screen text is the backup, not the other way round.

$dir = Join-Path $PSScriptRoot "..\assets\audio"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Add-Type -AssemblyName System.Speech
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo 22050, `
	([System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen), `
	([System.Speech.AudioFormat.AudioChannel]::Mono)

function Save-Phrase($path, $text, $rate, $pitch) {
	$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
	# Zira is the friendlier of the two stock voices; fall back if absent.
	try { $s.SelectVoice('Microsoft Zira Desktop') } catch {}
	$s.SetOutputToWaveFile($path, $fmt)
	$ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' " +
		"xml:lang='en-US'><prosody rate='$rate' pitch='$pitch' volume='loud'>" +
		"$text</prosody></speak>"
	$s.SpeakSsml($ssml)
	$s.SetOutputToNull()
	$s.Dispose()
	Write-Host "wrote $path"
}

$shapes = @('circle', 'square', 'triangle', 'rectangle', 'star', 'heart')

foreach ($name in $shapes) {
	$word = (Get-Culture).TextInfo.ToTitleCase($name)
	Save-Phrase (Join-Path $dir "shape_$name.wav") "$word!" '+8%' '+18%'
	# The instruction is a touch slower - it is a question being asked, and it
	# has to survive being heard once by someone who is three.
	Save-Phrase (Join-Path $dir "find_$name.wav") "Find the $name!" '-4%' '+16%'
}

Save-Phrase (Join-Path $dir "say_wellDone.wav") "Well done!" '+5%' '+22%'
Save-Phrase (Join-Path $dir "say_tryAgain.wav") "Try again!" '-2%' '+14%'
