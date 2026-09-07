package vmodchart.objects;

import flixel.math.FlxAngle;
import flixel.math.FlxPoint;
import flixel.util.FlxDestroyUtil;
import funkin.graphics.FunkinSprite;
import funkin.play.notes.Strumline;

import StringTools;

class CoverSprite extends FunkinSprite {
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
    public var isPlayer:Bool = false;
    public var isPixel:Bool = false;
    public var coverOffset(default, null):FlxPoint = new FlxPoint();

    public function new(noteStyle:NoteStyle) {
        super();
        var leAtlas:Null<FlxFramesCollection> = noteStyle.buildHoldCoverFrames(false);
        if (leAtlas == null) throw 'Could not load spritesheet for note style: ${noteStyle.id}';

        this.frames = leAtlas;
        final coverAssets = noteStyle._data.assets.holdNoteCover;
        this.isPixel = coverAssets?.isPixel ?? false;
        this.antialiasing = !isPixel;
        scale.set(coverAssets?.scale ?? 1.0, coverAssets?.scale ?? 1.0);
        updateHitbox();

        for (direction in Strumline.DIRECTIONS) {
            var animData:Null<Array<AnimationData>> = noteStyle.fetchHoldCoverAnimationData(direction);
            if (animData != null) {
                animData[1].looped = true;
                for (anim in animData) {
                    if (anim.frameIndices != null && anim.frameIndices.length > 0)
                        animation.addByIndices(anim.name, anim.prefix, anim.frameIndices, '', anim.frameRate ?? 24, anim.looped ?? false, anim.flipX ?? false, anim.flipY ?? false);
                    else 
                        animation.addByPrefix(anim.name, anim.prefix, anim.frameRate ?? 24, anim.looped ?? false, anim.flipX ?? false, anim.flipY ?? false);
                }
            }
        }
        animation.onFinish.add(onAnimationFinished);
        coverOffset.set(12 - (noteStyle.getHoldCoverOffsets()[0] * scale.x), -48 - (noteStyle.getHoldCoverOffsets()[1] * scale.y));
    }

    public function positionToStrumline(strumline:Strumline):Void {
        var strumNote = strumline.getByDirection(noteDirection);
        x = strumNote.x + (strumNote.width - width) / 2 - (coverOffset.x / scale.x);
        y = strumNote.y + (strumNote.height - height) / 2 - (coverOffset.y / scale.y);
    }

    public function setOrigin():Void {
        centerOrigin();
        origin.x += (coverOffset.x / scale.x);
        origin.y += (coverOffset.y / scale.y);
        if (isPixel) {
            origin.x = Math.floor(origin.x);
            origin.y = Math.floor(origin.y);
        }
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

    override public function destroy():Void {
        super.destroy();
        coverOffset = FlxDestroyUtil.put(coverOffset);
    }

    public function onAnimationFinished(animationName:String):Void {
        if (StringTools.startsWith(animationName, 'holdCoverStart')) playContinue();
        if (StringTools.startsWith(animationName, 'holdCoverEnd')) kill();
    }
}