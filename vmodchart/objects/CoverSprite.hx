package vmodchart.objects;

import flixel.FlxSprite;
import flixel.math.FlxAngle;
import funkin.play.notes.Strumline;
import funkin.util.assets.FlxAnimationUtil;

import StringTools;

class CoverSprite extends FlxSprite {
    public var noteDirection:NoteDirection = 0;
    public var colorName(get, never):String;
    function get_colorName() {
        switch (noteDirection) {
            case 0: return 'Purple';
            case 1: return 'Blue';
            case 2: return 'Green';
            case 3: return 'Red';
            default: return 'None';
        }
    }
    public var isPlayer:Bool;

    public function new(noteStyle:NoteStyle) {
        super();
        // TODO: fix the hold covers on the pixel notestyle
        var leAtlas = noteStyle.buildHoldCoverFrames(false);
        if (leAtlas == null) throw 'Could not load spritesheet for note style: ${noteStyle.id}';

        frames = leAtlas;
        final coverAssets = noteStyle._data.assets.holdNoteCover;
        antialiasing = !(coverAssets?.isPixel ?? false);
        scale.set(coverAssets?.scale ?? 1.0, coverAssets?.scale ?? 1.0);
        updateHitbox();

        for (direction in Strumline.DIRECTIONS) {
            var animData:Null<Array<AnimationData>> = noteStyle.fetchHoldCoverAnimationData(direction);
            //trace(animData);
            if (animData != null) {
                animData[1].looped = true;
                for (anim in animData) {
                    animation.addByPrefix(anim.name, anim.prefix, anim.frameRate ?? 24, anim.looped ?? false, anim.flipX ?? false, anim.flipY ?? false);
                }
            }
        }
        animation.onFinish.add(onAnimationFinished);
    }

    public function positionToStrumline(strumline:Strumline):Void {
        var strumNote = strumline.strumlineNotes.members[noteDirection];
        x = strumNote.x + (strumNote.width - width) / 2 + (strumline.noteStyle.getHoldCoverOffsets()[0] * scale.x) - 12;
        y = strumNote.y + (strumNote.height - height) / 2 + (strumline.noteStyle.getHoldCoverOffsets()[1] * scale.y) + 48;
    }

    public function setOrigin():Void {
        origin.y = (height / 2) - 48;
        origin.x = (width / 2) + 12;
    }

    public function playAnim(name:String):Void {
        animation.play(name);
        centerOffsets();
        setOrigin();
    }

    public function playStart():Void {
        playAnim('holdCoverStart$colorName');
    }

    public function playContinue():Void {
        playAnim('holdCover$colorName');
    }

    public function playEnd():Void {
        if (isPlayer) playAnim('holdCoverEnd$colorName');
        else kill();
    }

    override public function kill():Void {
        visible = false;
        super.kill();
    }

    override public function revive():Void {
        visible = true;
        super.revive();
        playStart();
    }

    public function onAnimationFinished(animationName:String):Void {
        if (StringTools.startsWith(animationName, 'holdCoverStart')) playContinue();
        if (StringTools.startsWith(animationName, 'holdCoverEnd')) kill();
    }
}