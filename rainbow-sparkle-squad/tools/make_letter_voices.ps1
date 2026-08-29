# Render the spoken phonics clips with the built-in Windows voice (SAPI).
#
#   powershell -File tools/make_letter_voices.ps1
#
# Output, into assets/audio/, mono 22050 Hz 16-bit PCM:
#   snd_<letter>.wav    the letter's SOUND, said alone - used while blending
#   key_<letter>.wav    "S says sss, like snake" - free play and first meeting
#   spell_<word>.wav    "Can you spell... pig?" - the round's instruction
#   said_<word>.wav     "Pig!" - the reward for finishing a word
#
# HONEST LIMITATION, and the reason snd_ and key_ are separate files:
# SAPI has no reliable way to say a bare phoneme. Asked for "t" it says the
# letter NAME ("tee"), and the usual workarounds ("tuh") add a schwa that
# phonics teaching specifically discourages - you want /t/, not "tuh", or
# blending c-a-t gives "cuh-a-tuh". The spellings below are the closest this
# voice gets, and the continuants (s, n, m) come out much better than the stops
# (t, p, d, g).
#
# So the key_ clips carry the real teaching: sound plus a keyword, which is how
# phonics is actually taught and which stays unambiguous even when the isolated
# phoneme is imperfect. The snd_ clips are the short ones used mid-word.
#
# These are placeholders in the sense that matters: the file names and the
# pipeline are the contract, so a real recorded voice can be dropped straight in
# over them with no code change. That is the recommended upgrade.

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

# letter -> (spoken sound, keyword). The first six are Letters and Sounds
# Phase 2 Set 1 (s a t p i n); the rest extend it just far enough to spell the
# six words the game uses.
$letters = [ordered]@{
	's' = @('ssss',  'snake')
	'a' = @('a',     'apple')
	't' = @('t',     'tiger')
	'p' = @('p',     'panda')
	'i' = @('ih',    'igloo')
	'n' = @('nnn',   'nest')
	'm' = @('mmm',   'moon')
	'd' = @('d',     'duck')
	'g' = @('g',     'goat')
	'o' = @('o',     'octopus')
}

foreach ($k in $letters.Keys) {
	$sound = $letters[$k][0]
	$word = $letters[$k][1]
	Save-Phrase (Join-Path $dir "snd_$k.wav") "$sound" '-8%' '+16%'
	Save-Phrase (Join-Path $dir "key_$k.wav") `
		"$($k.ToUpper()) says $sound, like $word." '-4%' '+16%'
}

# Six words, each spelled from the ten letters above with no letter repeated -
# a repeat would need one figure touched twice in a round, which the lighting
# cannot express.
$words = @('pig', 'dog', 'sat', 'map', 'tin', 'pot')
foreach ($w in $words) {
	Save-Phrase (Join-Path $dir "spell_$w.wav") "Can you spell... $w?" '-6%' '+14%'
	Save-Phrase (Join-Path $dir "said_$w.wav") `
		"$((Get-Culture).TextInfo.ToTitleCase($w))!" '+4%' '+20%'
}
