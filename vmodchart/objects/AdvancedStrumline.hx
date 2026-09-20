package vmodchart.objects;

import flixel.group.FlxSpriteGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import flixel.math.FlxAngle;
import flixel.math.FlxMath;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;

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

    public var strumNoteOffset(default, null):FlxPoint = new FlxPoint();
    public var strumCenter(default, never):Float = -Strumline.INITIAL_OFFSET + (Strumline.STRUMLINE_SIZE / 2);

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

        final strumOffsets = noteStyle.getStrumlineOffsets();
        strumNoteOffset.set(strumOffsets[0], strumOffsets[1]);
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
        if (!showNotesplash || !noteStyle.isNoteSplashEnabled()) return;
        var splash:NoteSplash = constructNoteSplash();

        if (splash != null) {
            final strumNote:StrumlineNote = getByDirection(direction);
            splash.play(direction);
            splash.x = (strumNote.x - strumNoteOffset.x) + (noteStyle.getSplashOffsets()[0] * splash.scale.x);
            splash.y = (strumNote.y - strumNoteOffset.y) - Strumline.INITIAL_OFFSET + (noteStyle.getSplashOffsets()[1] * splash.scale.y);
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
    
    public var noteUpdate:(modEvent:Dynamic)->Void;
    public var postNoteUpdate:(modEvent:Dynamic)->Void;

    public function getSongPosition(?delta:Bool = false):Float {
        return noteSongPosition != null? noteSongPosition(delta) : (delta? conductorInUse.getTimeWithDelta() : conductorInUse.songPosition);
    }

    public function getNoteY(strumTime:Float):Float {
        if (noteYFunction != null) {
            noteYFunction();
            return;
        }
        if (conductorInUse == null) conductorInUse = Conductor.instance;
        return Constants.PIXELS_PER_MS * (getSongPosition(true) - strumTime) * -scrollSpeed;
    }

    public function updateNotePosition(note:Dynamic, isSustain:Bool) {
        if (!(note is NoteSprite) && note.toString() != 'PolymodScriptClass<vmodchart.objects.SustainSprite>') return;
        if (note == null || !note.alive) return;

        if (isSustain == null) isSustain = note.toString() == 'PolymodScriptClass<vmodchart.objects.SustainSprite>';
        final direction:NoteDirection = isSustain? note.noteDirection : note.direction;

        var strumNote:StrumlineNote = getByDirection(direction);
        var notePos:Float = getNoteY(note.strumTime);

        final strumX:Float = strumNote.x + strumCenter - (note.width / 2) - strumNoteOffset.x;
        final strumY:Float = strumNote.y + strumCenter - (!isSustain? note.height / 2 : 0) - strumNoteOffset.y;
        var strumPos:FlxPoint = FlxPoint.get(strumX, strumY);

        var modEvent = new ModchartEvent(note, strumNote, direction, isSustain, notePos, strumPos);
        if (noteUpdate != null) noteUpdate(modEvent);
        if (modEvent.eventCanceled) {
            if (postNoteUpdate != null) postNoteUpdate(modEvent);
            strumPos.put();
            return;
        }

        notePos = modEvent.notePosition;
        strumPos = modEvent.strumPosition;

        final strumAngle:Float = FlxMath.wrap(isDownscroll? 180 - strumNote.angle : strumNote.angle, 0, 360);
        final xPos:Float = notePos * -Math.sin(strumAngle * FlxAngle.TO_RAD);
        final yPos:Float = notePos * Math.cos(strumAngle * FlxAngle.TO_RAD);

        note.angle = strumNote.angle;
        note.skew.set(strumNote.skew.x, strumNote.skew.y);
        note.setPosition(strumPos.x, strumPos.y);
        if (isSustain) {
            note.visible = true;
            if (!note.hitNote || note.missedNote) {
                note.x += xPos;
                note.y += yPos;
                if (note.missedNote && (note.fullSustainLength > note.sustainLength)) 
                    note.y += (note.fullSustainLength - note.sustainLength) * Constants.PIXELS_PER_MS;
            }

            if (note.cover != null) {
                note.cover.angle = FlxMath.wrap(isDownscroll? 180 - note.angle : note.angle, 0, 360);
                note.cover.skew.set(note.skew.x, note.skew.y);
            }
        }
        else {
            note.x += xPos;
            note.y += yPos;
        }

        if (postNoteUpdate != null) postNoteUpdate(modEvent);
        strumPos.put();
    }

    public function updateNotes():Void {
        super.updateNotes();
        if (noteData.length == 0) return;

        for (note in notes.members) {
            if (note == null || !note.alive) continue;
            updateNotePosition(note, false);
        }

        for (hold in holdSprites.members) {
            if (hold == null || !hold.alive) continue;
            final direction:Int = hold.noteDirection;
            
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
                hold.kill();
            }
            else if (conductorInUse.songPosition > hold.strumTime && hold.hitNote) {
                holdConfirm(direction);
                hold.sustainLength = (hold.strumTime + hold.fullSustainLength) - getSongPosition(false);
            }

            if (hold.cover != null) {
                var cover:Null<CoverSprite> = hold.cover;
                cover.positionToStrumline(this);
                cover.visible = true;

                if (hold.missedNote) {
                    cover.visible = false;
                    cover.kill();
                }
                else if (hold.hitNote && hold.sustainLength <= 0) cover.playEnd();
            }
            updateNotePosition(hold, true);
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

    override public function destroy():Void {
        super.destroy();
        strumNoteOffset = FlxDestroyUtil.put(strumNoteOffset);
    }
}