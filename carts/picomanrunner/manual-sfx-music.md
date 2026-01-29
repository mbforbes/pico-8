## 2.4 SFX Editor
There are 64 SFX ("sound effects") in a cartridge, used for both sound and music.

Each SFX has 32 notes, and each note has:
  A frequency   (C0..C5)
  An instrument (0..7)
  A volume      (0..7)
  An effect     (0..7)

Each SFX also has these properties:

  A play speed (SPD) : the number of 'ticks' to play each note for.
    // This means that 1 is fastest, 3 is 3x as slow, etc.

  Loop start and end : this is the note index to loop back and to
    // Looping is turned off when the start index >= end index

When only the first of the 2 numbers is used (and the second one is 0), it is taken to mean the number of notes to be played. This is normally not needed for sound effects (you can just leave the remaining notes empty), but is useful for controlling music playback.

There are 2 modes for editing/viewing a SFX: Pitch mode (more suitable for sound effects) and tracker mode (more suitable for music). The mode can be changed using the top-left buttons, or toggled with TAB.

▨ Pitch Mode
Click and drag on the pitch area to set the frequency for each note, using the currently selected instrument (indicated by colour).

Hold shift to apply only the selected instrument.
Hold CTRL to snap entered notes to the C minor pentatonic scale.
Right click to grab the instrument of that note.

▨ Tracker Mode
Each note shows: frequency octave instrument volume effect
To enter a note, use q2w3er5t6y7ui zsxdcvgbhnjm (piano-like layout)
Hold shift when entering a note to transpose -1 octave .. +1 octave
New notes are given the selected instrument/effect values
To delete a note, use backspace or set the volume to 0

Click and then shift-click to select a range that can be copied (CTRL-C) and pasted (CTRL-V). Note that only the selected attributes are copied. Double-click to select all attributes of a single note.

Navigation:
  PAGEUP/DOWN or CTRL-UP/DOWN to skip up or down 4 notes
  HOME/END to jump to the first or last note
  CTRL-LEFT/RIGHT to jump across columns

▨ Controls for both modes
- + to navigate the current SFX
< > to change the speed. SPACE to play/stop
SHIFT-SPACE to play from the current SFX quarter (group of 8 notes)
A to release a looping sample
Left click or right click to increase / decrease the SPD or LOOP values
  // Hold shift when clicking to increase / decrease by 4
  // Alternatively, click and drag left/right or up/down
Shift-click an instrument, effect, or volume to apply to all notes.

▨ Effects
0 none
1 slide          //  Slide to the next note and volume
2 vibrato        //  Rapidly vary the pitch within one quarter-tone
3 drop           //  Rapidly drop the frequency to very low values
4 fade in        //  Ramp the volume up from 0
5 fade out       //  Ramp the volume down to 0
6 arpeggio fast  //  Iterate over groups of 4 notes at speed of 4
7 arpeggio slow  //  Iterate over groups of 4 notes at speed of 8

If the SFX speed is <= 8, arpeggio speeds are halved to 2, 4

▨ Filters
Each SFX has 5 filter switches that can be accessed while in tracker mode:

NOIZ:      Generate pure white noise (applies only to instrument 6)
BUZZ:      Various alterations to the waveform to make it sound more buzzy
DETUNE-1:  Detunes a second voice to create a flange-like effect
DETUNE-2:  Various second voice tunings, mostly up or down an octave
REVERB:    Apply an echo with a delay of 2 or 4 ticks
DAMPEN:    Low pass filter at 2 different levels

When BUZZ is used with instrument 6, and NOIZ is off, pure brown noise is generated.

## 2.5 Music Editor
Music in PICO-8 is controlled by a sequence of 'patterns'. Each pattern is a list of 4 numbers indicating which SFX will be played on that channel.

▨ Flow control
Playback flow can be controlled using the 3 buttons at the top right.

When a pattern has finished playing, the next pattern is played unless:

- there is no data left to play (music stops)
- a STOP command is set on that pattern (the third button)
- a LOOP BACK command is set (the 2nd button), in which case the music player searches
  back for a pattern with the LOOP START command set (the first button) or returns to
  pattern 0 if none is found.

When a pattern has SFXes with different speeds, the pattern finishes playing when the left-most non-looping channel has finished playing. This can be used to set up double-time drum beats or unusual polyrhythms.

For time signatures like 3/4 where less than 32 rows should be played before jumping to the next pattern, the length of a SFX can be set by adjusting only the first loop position and leaving the second one as zero. This will show up in the sfx editor as "LEN" (for "Length") instead of "LOOP".

▨ Copying and Pasting Music
To select a range of patterns: click once on the first pattern in the pattern navigator, then shift-click on the last pattern. Selected patterns can be copied and pasted with CTRL-C and CTRL-V. When pasting into another cartridge, the SFX that each pattern points to will also be pasted (possibly with a different index) if it does not already exist.

▨ SFX Instruments
In addition to the 8 built-in instruments, custom instruments can be defined using the first 8 SFX. Use the toggle button to the right of the instruments to select an index, which will show up in the instrument channel as green instead of pink.

When an SFX instrument note is played, it essentially triggers that SFX, but alters the note's attributes:

  Pitch is added relative to C2
  Volume is multiplied
  Effects are applied on top of the SFX instrument's effects
  Any filters that are on in the SFX instrument are enabled for that note

For example, a simple tremolo effect could be implemented by defining an instrument in SFX 0 that rapidly alternates between volume 5 and 2. When using this instrument to play a note, the volume can further be altered as usual (via the volume channel or using the fade in/out effects). In this way, SFX instruments can be used to control combinations of detailed changes in volume, pitch and texture.

SFX instruments are only retriggered when the pitch changes, or the previous note has zero volume. This is useful for instruments that change more slowly over time. For example: a bell that gradually fades out. To invert this behaviour, effect 3 (normally 'drop') can be used when triggering the note. All other effect values have their usual meaning when triggering SFX instruments.

▨ Waveform Instruments
Waveform instruments function the same way as SFX instruments, but consist of a custom 64-byte looping waveform. Click on the waveform toggle button in the SFX editor to use SFX 0..7 as a waveform instrument. In this mode, samples can be drawn with the mouse.

▨ Scale Snapping
When drawing notes in pitch mode, hold CTRL to snap to the currently defined scale. This is the C minor pentatonic scale by default, but can be customised using the scale editor mode. There is a little keyboard icon on the bottom right to toggle this. There are 2 tranpose buttons, 1 invert button, and 3 scale preset buttons:

Dim   Diminished 7th scale // invert to get a whole-half scale
Maj   Major scale          // invert to get pentatonic
Who   Whole tone scale     // invert to get.. the other whole tone scale

Changing the scale does not alter the current SFX, it is only when drawing new notes with CTRL held down that the scale is applied.
