package vmodchart.objects;

import flixel.group.FlxSpriteGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxAngle;

import funkin.play.notes.Strumline;
import funkin.play.notes.SustainTrail;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.notekind.NoteKind;
import funkin.play.notes.notekind.NoteKindManager;
import funkin.util.GRhythmUtil;

class AdvancedStrumline extends Strumline {
    public var holdSprites:FlxTypedSpriteGroup<SustainSprite>;
    public var coverSprites:FlxTypedSpriteGroup<CoverSprite>;

    public var dummySustain:SustainTrail;
    public var dummyNote:NoteSprite;
    
    public var oldSustainJitter:Bool = false;
    public var holdTimer:Float = 0;

    public function new(noteStyle:NoteStyle, isPlayer:Bool, ?scrollSpeed:Float) {
        super(noteStyle, isPlayer, scrollSpeed);
        remove(holdNotes);

        holdSprites = new FlxTypedSpriteGroup();
        holdSprites.zIndex = 20;
        add(holdSprites);

        remove(noteHoldCovers);
        coverSprites = new FlxTypedSpriteGroup();
        coverSprites.zIndex = 40;
        add(coverSprites);

        dummySustain = new SustainTrail(0, 0, noteStyle);
        dummyNote = new NoteSprite(noteStyle);
    }

    override public function buildHoldNoteSprite(note:SongNoteData):SustainSprite {
        var sustainSprite:SustainSprite = holdSprites.getFirstAvailable();

        if (sustainSprite == null) {
            sustainSprite = new SustainSprite(0, 0, noteStyle);
            holdSprites.add(sustainSprite);
        }
        else 
            sustainSprite.revive();

        if (sustainSprite != null) {
            var noteKind:NoteKind = NoteKindManager.getNoteKind(note.kind);
            var noteKindStyle:NoteStyle = NoteKindManager.getNoteStyle(note.kind, this.noteStyle.id);
            if (noteKindStyle == null) noteKindStyle = NoteKindManager.getNoteStyle(note.kind, null);
            if (noteKindStyle == null) noteKindStyle = this.noteStyle;

            sustainSprite.parentStrumline = this;
            sustainSprite.noteData = note;
            sustainSprite.strumTime = note.time;
            sustainSprite.noteDirection = note.getDirection();
            sustainSprite.fullSustainLength = note.length;
            sustainSprite.sustainLength = note.length;
            sustainSprite.missedNote = false;
            sustainSprite.hitNote = false;
            sustainSprite.visible = true;
            sustainSprite.alpha = 1.0;
            sustainSprite.graphic.destroyOnNoUse = false;
            if (noteKind != null) sustainSprite.scoreable = noteKind.scoreable;

            sustainSprite.setPosition(-9999, -9999);
        }

        return null;
    }

    override public function playNoteSplash(direction:NoteDirection):Void {
        // TODO: Fix splash offsets.
        if (!showNotesplash || !noteStyle.isNoteSplashEnabled()) return;
        var splash:NoteSplash = constructNoteSplash();

        if (splash != null) {
            final strumNote:StrumlineNote = getByDirection(direction);
            splash.play(direction);

            splash.setPosition(strumNote.x, strumNote.y);
            splash.x += noteStyle.getSplashOffsets()[0] * splash.scale.x;
            splash.y += noteStyle.getSplashOffsets()[1] * splash.scale.y;

            splash.graphic.destroyOnNoUse = false;
        }
    }

    public function playCoverSprite(holdSprite:SustainSprite):Void {
        if (!showNotesplash || !noteStyle.isHoldNoteCoverEnabled()) return;
        var coverSprite:CoverSprite = coverSprites.getFirstAvailable();

        if (coverSprite == null) {
            coverSprite = new CoverSprite(noteStyle);
            coverSprites.add(coverSprite);
        }
        else 
            coverSprite.revive();

        holdSprite.cover = coverSprite;
        coverSprite.noteDirection = holdSprite.noteDirection;
        coverSprite.isPlayer = this.isPlayer;
        coverSprite.playStart();
        coverSprite.positionToStrumline(this);
    }

    override public function hitNote(note:NoteSprite, removeNote:Bool = true):Void {
        playConfirm(note.direction);
        note.hasBeenHit = true;
        holdTimer = 0;

        if (removeNote) killNote(note);
        else {
            note.alpha = 0.5;
            note.desaturate();
        }

        if (note.noteData.length <= 0) return;

        var sustainNote = null;
        for (holdSprite in holdSprites.members) {
            if (holdSprite == null || !holdSprite.alive) continue;
            if ((holdSprite.strumTime == note.noteData.time) && (holdSprite.noteDirection == note.direction)) {
                sustainNote = holdSprite;
                break;
            }
        }

        if (sustainNote != null) {
            sustainNote.hitNote = true;
            sustainNote.missedNote = false;

            sustainNote.sustainLength = Math.min(sustainNote.fullSustainLength, (sustainNote.strumTime + sustainNote.fullSustainLength) - conductorInUse.songPosition);
            playCoverSprite(sustainNote);
        }
    }

    public function updateNotes():Void {
        super.updateNotes();
        if (noteData.length == 0) return;

        for (note in notes.members) {
            if (note == null || !note.alive) continue;
            final direction:Int = note.direction;
            final strumNote:StrumlineNote = getByDirection(direction);

            final notePos:Float = GRhythmUtil.getNoteY(note.strumTime, scrollSpeed, false, conductorInUse);
            final daAngle = strumNote.angle;
            final xPos:Float = notePos * -Math.sin(daAngle * FlxAngle.TO_RAD);
            final yPos:Float = notePos * Math.cos(daAngle * FlxAngle.TO_RAD);
            
            final strumX:Float = strumNote.x + (strumNote.width - note.width) / 2;
            final strumY:Float = strumNote.y + (strumNote.height - note.height) / 2;

            if (!customPositionData) {
                note.angle = daAngle;
                note.skew.set(strumNote.skew.x, strumNote.skew.y);
                note.setPosition(strumX + xPos, strumY + yPos);
            }
        }

        for (holdSprite in holdSprites.members) {
            if (holdSprite == null || !holdSprite.alive) continue;
            final direction:Int = holdSprite.noteDirection;
            final strumNote:StrumlineNote = getByDirection(direction);

            final notePos:Float = GRhythmUtil.getNoteY(holdSprite.strumTime, scrollSpeed, false, conductorInUse);
            final daAngle = strumNote.angle;
            final xPos:Float = notePos * -Math.sin(daAngle * FlxAngle.TO_RAD);
            final yPos:Float = notePos * Math.cos(daAngle * FlxAngle.TO_RAD);

            final strumX:Float = strumNote.x + (strumNote.width - holdSprite.width) / 2;
            final strumY:Float = strumNote.y + strumNote.height / 2;

            final renderWindowEnd:Float = holdSprite.strumTime + holdSprite.fullSustainLength + Constants.HIT_WINDOW_MS + (renderDistanceMs / 8);
            holdSprite.angle = daAngle;
            holdSprite.skew.set(strumNote.skew.x, strumNote.skew.y);
            holdSprite.visible = true;

            if (holdSprite.cover != null) {
                holdSprite.cover.angle = daAngle;
                holdSprite.cover.skew.set(strumNote.skew.x, strumNote.skew.y);
                holdSprite.cover.positionToStrumline(this);
            }
            
            if (conductorInUse.songPosition > holdSprite.strumTime && holdSprite.hitNote && !holdSprite.missedNote) {
                if (isPlayer && !isKeyHeld(direction)) {
                    playStatic(direction);
                    holdSprite.missedNote = true;
                    holdSprite.alpha = 0;
                }
            }

            if (holdSprite.missedNote && conductorInUse.songPosition >= renderWindowEnd) {
                holdSprite.kill();
            }
            else if (holdSprite.hitNote && holdSprite.sustainLength <= 0) {
                if (isKeyHeld(direction)) playPress(direction);
                else playStatic(direction);

                if (holdSprite.cover != null) holdSprite.cover.playEnd();
                holdSprite.kill();
            }
            else if (holdSprite.missedNote && (holdSprite.fullSustainLength > holdSprite.sustainLength)) {
                if (!customPositionData) 
                    holdSprite.setPosition(strumX + xPos, strumY + yPos + ((holdSprite.fullSustainLength - holdSprite.sustainLength) * Constants.PIXELS_PER_MS));
                if (holdSprite.cover != null) holdSprite.cover.kill();
            }
            else if (conductorInUse.songPosition > holdSprite.strumTime && holdSprite.hitNote) {
                holdConfirm(direction);
                
                if (!customPositionData) {
                    holdSprite.sustainLength = (holdSprite.strumTime + holdSprite.fullSustainLength) - conductorInUse.songPosition;
                    holdSprite.setPosition(strumX, strumY);
                }
            }
            else {
                if (!customPositionData) 
                    holdSprite.setPosition(strumX + xPos, strumY + yPos);
            }
        }
    }

    public function vwooshNotes():Void {
        super.vwooshNotes();
        for (holdSprite in holdSprites.members) {
            if (holdSprite == null || !holdSprite.alive) continue;
            holdSprites.remove(holdSprite);
            holdNotesVwoosh.add(holdSprite);

            var targetY:Float = isDownscroll? holdSprite.y - FlxG.height : FlxG.height + holdSprite.y;
            FlxTween.tween(holdSprite, {y: targetY}, 0.5, {ease: FlxEase.expoIn,
                onComplete: function(twn) {
                    holdSprite.kill();
                    holdNotesVwoosh.remove(holdSprite, true);
                    holdSprite.destroy();
                }
            });
        }
    }

    public function clean():Void {
        super.clean();
        for (sustain in holdSprites) {
            if (sustain == null) continue;
            sustain.kill();
        }

        for (cover in coverSprites) {
            if (cover == null) continue;
            cover.kill();
        }
    }
}