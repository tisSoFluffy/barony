# Render the spoken "One!" .. "Ten!" star-pickup clips with the built-in
# Windows voice (SAPI). Output: assets/audio/count_01.wav .. count_10.wav,
# mono 22050 Hz 16-bit PCM, which Godot imports as-is.
#
#   powershell -File tools/make_count_voices.ps1
#
# Re-run to regenerate (e.g. to try the other voice or a different prosody).

$dir = Join-Path $PSScriptRoot "..\assets\audio"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

Add-Type -AssemblyName System.Speech
$words = @('One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Ten')
$fmt = New-Object System.Speech.AudioFormat.SpeechAudioFormatInfo 22050, `
	([System.Speech.AudioFormat.AudioBitsPerSample]::Sixteen), `
	([System.Speech.AudioFormat.AudioChannel]::Mono)

for ($i = 0; $i -lt 10; $i++) {
	$path = Join-Path $dir ("count_{0:D2}.wav" -f ($i + 1))
	$s = New-Object System.Speech.Synthesis.SpeechSynthesizer
	# Zira is the friendlier of the two stock voices; fall back if absent.
	try { $s.SelectVoice('Microsoft Zira Desktop') } catch {}
	$s.SetOutputToWaveFile($path, $fmt)
	$ssml = "<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' " +
		"xml:lang='en-US'><prosody rate='+8%' pitch='+18%' volume='loud'>" +
		"$($words[$i])!</prosody></speak>"
	$s.SpeakSsml($ssml)
	$s.SetOutputToNull()
	$s.Dispose()
	Write-Host "wrote $path"
}
