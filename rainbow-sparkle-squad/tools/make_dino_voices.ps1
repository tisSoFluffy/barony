# Render the spoken dinosaur clips with the built-in Windows voice (SAPI).
#
#   powershell -File tools/make_dino_voices.ps1
#
# Output, into assets/audio/, mono 22050 Hz 16-bit PCM:
#   dino_<name>.wav    "Tyrannosaurus Rex!"   - said when a dinosaur is touched
#   ask_biggest.wav    "Find the biggest dinosaur!"
#   ask_smallest.wav   "Find the smallest dinosaur!"
#   ask_flies.wav      "Which dinosaur can fly?"
#
# The roars are NOT here - SAPI cannot roar. Those are synthesised by
# tools/make_dino_roars.py, pitched to each dinosaur's size.
#
# "Tyrannosaurus" is spelled out phonetically below because SAPI mangles it
# otherwise; the others it says correctly as written.

$dir = Join-Path $PSScriptRoot "..\assets\audio"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Add-Type -AssemblyName System.Speech
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo 22050, `
	([System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen), `
	([System.Speech.AudioFormat.AudioChannel]::Mono)

function Save-Phrase($path, $text, $rate, $pitch) {
	$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
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

# key -> spoken text. Slower than the other islands on purpose: these are long
# words, and the whole appeal is a three-year-old learning to say them.
$dinos = [ordered]@{
	'trex'        = 'Tie-ranno-sore-us Rex!'
	'triceratops' = 'Try-serra-tops!'
	'stegosaurus' = 'Stego-sore-us!'
	'pteranodon'  = 'Ter-ann-oh-don!'
}

foreach ($k in $dinos.Keys) {
	Save-Phrase (Join-Path $dir "dino_$k.wav") $dinos[$k] '-14%' '+12%'
}

Save-Phrase (Join-Path $dir "ask_biggest.wav")  'Find the biggest dinosaur!'  '-6%' '+14%'
Save-Phrase (Join-Path $dir "ask_smallest.wav") 'Find the smallest dinosaur!' '-6%' '+14%'
Save-Phrase (Join-Path $dir "ask_flies.wav")    'Which dinosaur can fly?'     '-6%' '+14%'
