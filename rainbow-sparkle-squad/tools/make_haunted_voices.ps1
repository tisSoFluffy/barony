# Render the spoken Haunted House clips with the built-in Windows voice (SAPI).
#
#   powershell -File tools/make_haunted_voices.ps1
#
# Output, into assets/audio/, mono 22050 Hz 16-bit PCM:
#   emotion_<feeling>.wav   "Happy!"              - said when a ghost is touched
#   feel_<feeling>.wav      "Who looks happy?"    - the round's question
#
# The questions are about FEELINGS, which is the one subject on this island that
# is about people rather than things - see HauntedHouse.gd for why these five
# feelings and not the textbook set.
#
# Said a little slower and warmer than the safari questions. A feeling word is
# the whole answer here, so it has to survive being heard once by someone who
# cannot read the backup text on screen.

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

$feelings = @('happy', 'sad', 'angry', 'scared', 'sleepy')
foreach ($f in $feelings) {
	$word = (Get-Culture).TextInfo.ToTitleCase($f)
	Save-Phrase (Join-Path $dir "emotion_$f.wav") "$word!" '-6%' '+14%'
}

# One question per feeling. The feeling word carries the round, so it is spoken
# last and on its own - "Who looks ... happy?" - rather than buried mid-sentence.
$ask = [ordered]@{
	'happy'   = 'Who looks happy?'
	'sad'     = 'Who looks sad?'
	'angry'   = 'Who looks angry?'
	'scared'  = 'Who looks scared?'
	'sleepy'  = 'Who looks sleepy?'
}
foreach ($k in $ask.Keys) {
	Save-Phrase (Join-Path $dir "feel_$k.wav") $ask[$k] '-10%' '+14%'
}
