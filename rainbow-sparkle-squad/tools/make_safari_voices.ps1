# Render the spoken safari clips with the built-in Windows voice (SAPI).
#
#   powershell -File tools/make_safari_voices.ps1
#
# Output, into assets/audio/, mono 22050 Hz 16-bit PCM:
#   animal_<name>.wav   "Giraffe!"                       - said when touched
#   spy_<key>.wav       "Who has a very long neck?"      - the round's question
#
# The animal calls are NOT here - SAPI cannot roar or trumpet. Those are
# synthesised by tools/make_animal_sounds.py, pitched to each animal's size.
#
# The questions are deliberately about FEATURES rather than names. Dino Valley
# already asks about size and Shape Cove about names; asking "who has stripes"
# makes a child look at the animal and describe what they see, which is the one
# thing none of the other islands does.

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

$animals = @('giraffe', 'lion', 'hippo', 'elephant', 'zebra')
foreach ($a in $animals) {
	$word = (Get-Culture).TextInfo.ToTitleCase($a)
	Save-Phrase (Join-Path $dir "animal_$a.wav") "$word!" '-6%' '+14%'
}

# key -> question. One per animal, each naming a feature that is unmistakable on
# the model and absent from all the others.
$spy = [ordered]@{
	'neck'   = 'Who has a very long neck?'
	'mane'   = 'Who has a big fluffy mane?'
	'mouth'  = 'Who has the biggest mouth?'
	'trunk'  = 'Who has a long trunk?'
	'stripes' = 'Who has black and white stripes?'
}
foreach ($k in $spy.Keys) {
	Save-Phrase (Join-Path $dir "spy_$k.wav") $spy[$k] '-8%' '+14%'
}
