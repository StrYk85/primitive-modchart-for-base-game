package vmodchart.objects;

import flixel.group.FlxSpriteGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;

import funkin.Conductor;
import funkin.play.notes.Strumline;
import funkin.play.notes.SustainTrail;
import funkin.play.notes.NoteSprite;
import funkin.play.notes.notekind.NoteKind;
import funkin.play.notes.notekind.NoteKindManager;

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

            sustainSprite.setParams(note);
            sustainSprite.parentStrumline = this;
            sustainSprite.visible = true;
            sustainSprite.alpha = 1.0;
            sustainSprite.flipX = isDownscroll;
            sustainSprite.graphic.destroyOnNoUse = false;
            if (noteKind != null) sustainSprite.scoreable = noteKind.scoreable;

            sustainSprite.setPosition(-9999, -9999);
            sustainSprite.visibleLimit = 10;
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
            splash.setPosition(strumNote.x + (noteStyle.getSplashOffsets()[0] * splash.scale.x), strumNote.y + (noteStyle.getSplashOffsets()[1] * splash.scale.y));
            splash.graphic.destroyOnNoUse = false;
        }
    }

    public function playCoverSprite(hold:SustainSprite):Void {
        if (!showNotesplash || !noteStyle.isHoldNoteCoverEnabled()) return;
        var cover:CoverSprite = coverSprites.getFirstAvailable();

        if (cover == null) {
            cover = new CoverSprite(noteStyle);
            coverSprites.add(cover);
        }
        else 
            cover.revive();

        hold.cover = cover;
        cover.noteDirection = hold.noteDirection;
        cover.isPlayer = isPlayer;
        cover.playStart();
        cover.positionToStrumline(this);
        cover.visible = true;
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
        for (hold in holdSprites.members) {
            if (hold == null || !hold.alive) continue;
            if ((hold.strumTime == note.noteData.time) && (hold.noteDirection == note.direction)) {
                sustainNote = hold;
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

    public var noteYFunction:(strumTime:Float)->Float;
    public var noteSongPosition:(delta:Bool)->Float;

    public function getSongPosition(?delta:Bool = false):Float {
        return noteSongPosition != null? noteSongPosition(delta) : (delta? conductorInUse.getTimeWithDelta() : conductorInUse.songPosition);
    }

    public function getNoteY(strumTime:Float):Float {
        if (conductorInUse == null) conductorInUse = Conductor.instance;
        return Constants.PIXELS_PER_MS * (getSongPosition(true) - strumTime) * -scrollSpeed;
    }

    public function updateNotes():Void {
        super.updateNotes();
        if (noteData.length == 0) return;
        if (noteYFunction == null) noteYFunction = getNoteY;

        for (note in notes.members) {
            if (note == null || !note.alive) continue;
            if (!customPositionData) {
                final strumNote:StrumlineNote = getByDirection(note.direction);
                final notePos:Float = noteYFunction(note.strumTime);
                final strumAngle = FlxMath.wrap(isDownscroll? 180 - strumNote.angle : strumNote.angle, 0, 360);
                // TODO: Find a better way to center the note to the strumline note since the strumNote can change its width and height depending on the animation
                final strumX:Float = strumNote.x + (strumNote.width - note.width) / 2;
                final strumY:Float = strumNote.y + (strumNote.height - note.height) / 2;

                note.angle = strumNote.angle;
                note.skew.set(strumNote.skew.x, strumNote.skew.y);
                note.setPosition(strumX - (notePos * Math.sin(strumAngle * FlxAngle.TO_RAD)), strumY + (notePos * Math.cos(strumAngle * FlxAngle.TO_RAD)));
            }
        }

        for (hold in holdSprites.members) {
            if (hold == null || !hold.alive) continue;
            final direction:Int = hold.noteDirection;
            final strumNote:StrumlineNote = getByDirection(direction);

            final notePos:Float = noteYFunction(hold.strumTime);
            final strumAngle = FlxMath.wrap(isDownscroll? 180 - strumNote.angle : strumNote.angle, 0, 360);
            final xPos:Float = notePos * -Math.sin(strumAngle * FlxAngle.TO_RAD);
            final yPos:Float = notePos * Math.cos(strumAngle * FlxAngle.TO_RAD);
            var cover:Null<CoverSprite> = hold.cover;

            if (!customPositionData) {
                hold.angle = strumAngle;
                hold.skew.set(strumNote.skew.x, strumNote.skew.y);
                hold.setPosition(strumNote.x + (strumNote.width - hold.width) / 2, strumNote.y + strumNote.height / 2);
                hold.visible = true;

                if (cover != null) {
                    cover.angle = strumNote.angle;
                    cover.skew.set(hold.skew.x, hold.skew.y);
                    cover.positionToStrumline(this);
                    cover.visible = true;
                }
            }
            
            if (conductorInUse.songPosition > hold.strumTime && hold.hitNote && !hold.missedNote) {
                if (isPlayer && !isKeyHeld(direction)) {
                    playStatic(direction);
                    hold.missedNote = true;
                    hold.alpha = 0;
                }
            }

            final renderWindowEnd:Float = hold.strumTime + hold.fullSustainLength + Constants.HIT_WINDOW_MS + (renderDistanceMs / 8);
            if (hold.missedNote && conductorInUse.songPosition >= renderWindowEnd) hold.kill();
            else if (hold.hitNote && hold.sustainLength <= 0) {
                if (isKeyHeld(direction)) playPress(direction);
                else playStatic(direction);

                if (cover != null) cover.playEnd();
                hold.kill();
            }
            else if (hold.missedNote && (hold.fullSustainLength > hold.sustainLength)) {
                if (!customPositionData) {
                    hold.x += xPos;
                    hold.y += yPos + ((hold.fullSustainLength - hold.sustainLength) * Constants.PIXELS_PER_MS);
                }
                if (cover != null) cover.kill();
            }
            else if (conductorInUse.songPosition > hold.strumTime && hold.hitNote) {
                holdConfirm(direction);
                hold.sustainLength = (hold.strumTime + hold.fullSustainLength) - getSongPosition(false);
            }
            else {
                if (!customPositionData) {
                    hold.x += xPos;
                    hold.y += yPos;
                }
            }
        }
    }

    public function vwooshNotes():Void {
        super.vwooshNotes();
        for (hold in holdSprites.members) {
            if (hold == null || !hold.alive) continue;
            holdSprites.remove(hold);
            holdNotesVwoosh.add(hold);

            var targetY:Float = isDownscroll? hold.y - FlxG.height : FlxG.height + hold.y;
            FlxTween.tween(hold, {y: targetY}, 0.5, {ease: FlxEase.expoIn,
                onComplete: function(twn) {
                    hold.kill();
                    holdNotesVwoosh.remove(hold, true);
                    hold.destroy();
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