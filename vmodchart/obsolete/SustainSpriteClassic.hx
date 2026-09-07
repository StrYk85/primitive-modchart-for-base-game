package vmodchart.objects;

import flixel.FlxSprite;
import flixel.math.FlxAngle;
import flixel.math.FlxRect;
import funkin.play.notes.Strumline;
import funkin.play.notes.notestyle.NoteStyle;

import funkin.graphics.FunkinSprite;

class SustainSpriteClassic extends FunkinSprite {
    public static var TIP_OFFSET:Float = 2.0;
    public var tip:FlxSprite;

    public var noteData:Null<SongNoteData>;
    public var parentStrumline:Strumline;

    public var strumTime:Float = 0;
    public var noteDirection(default, set):NoteDirection = 0;
    function set_noteDirection(val):NoteDirection {
        noteDirection = val;
        animation.play(Std.string(noteDirection % 4));
        tip.animation.play(Std.string(noteDirection % 4));
        return val;
    }

    public var scoreable:Bool = true;
    public var hitNote:Bool = false;
    public var missedNote:Bool = false;
    public var handledMiss:Bool = false;

    public var fullSustainLength:Float = 0;
    public var sustainLength(default, set):Float = 0;
    function set_sustainLength(val):Float {
        if (val < 0.0) val = 0.0;
        sustainLength = val;
        recallibrateSustain();
        return val;
    }

    var previousScrollSpeed:Float = -1;
    var scrollSpeed(get, never):Float;
    function get_scrollSpeed() {
        return parentStrumline?.scrollSpeed ?? 1.0;
    }

    public var isPixel:Bool = false;

    public function new(dir:Int, susLength:Float, noteStyle:NoteStyle) {
        super();
        final assetPath:String = noteStyle.getHoldNoteAssetPath();
        final image = Assets.getBitmapData(assetPath);

        this.isPixel = noteStyle.isHoldNotePixel();

        var dirLength:Float = Strumline.DIRECTIONS.length * 2;
        loadGraphic(image, true, image.width / dirLength, image.height);
        tip = new FlxSprite();
        tip.loadGraphic(image, true, image.width / dirLength, image.height - (isPixel? 0 : TIP_OFFSET));

        if (isPixel) antialiasing = tip.antialiasing = false;
        
        for (direction in Strumline.DIRECTIONS) {
            animation.add(Std.string(direction), [direction * 2]);
            animation.add(Std.string(direction) + 'end', [(direction * 2) + 1]);
            tip.animation.add(Std.string(direction), [(direction * 2) + 1]);
        }

        final noteZoom:Float = noteStyle.fetchHoldNoteScale();
        setGraphicSize(this.width * noteZoom);
        tip.setGraphicSize(tip.width * noteZoom);
        tip.updateHitbox();

        this.noteDirection = dir;
        this.sustainLength = susLength;
    }

    public function recallibrateSustain() {
        final thingy = (sustainLength * Constants.PIXELS_PER_MS * scrollSpeed) - (tip.height / 2);
        scale.y = ((sustainLength * Constants.PIXELS_PER_MS * scrollSpeed) - tip.height / 2) / frameHeight;
        height = (Math.abs(scale.y) * frameHeight) + tip.height / 2;
        origin.set(width / 2, 0);
    }

    public function copySustain(oldie:SustainTrail) {
        noteData = oldie.noteData;
        strumTime = oldie.strumTime;
        noteDirection = oldie.noteDirection;
        fullSustainLength = oldie.fullSustainLength;
        sustainLength = oldie.sustainLength;
        parentStrumline = oldie.parentStrumline;
        scoreable = oldie.scoreable;
    }

    private function copyTip() {
        tip.x = x;
        tip.y = y;
        tip.angle = angle;
        tip.flipX = flipX;
        tip.alpha = alpha;
        tip.scrollFactor.x = scrollFactor.x;
        tip.scrollFactor.y = scrollFactor.y;
        tip.scale.x = scale.x;
        tip.blend = blend;
        tip.color = color;
        if (tip.cameras != cameras) tip.cameras = cameras;
    }

    private function resetParams() {
        strumTime = 0;
        noteDirection = 0;
        sustainLength = 0;
        fullSustainLength = 0;
        noteData = null;

        hitNote = false;
        missedNote = false;
    }

    override function update(elapsed:Float) {
        super.update(elapsed);
        if (previousScrollSpeed != scrollSpeed) {
            recallibrateSustain();
            previousScrollSpeed = scrollSpeed;
        }
    }

    override public function draw() {
        if (sustainLength <= 0) return;
        if (scale.y > 0) super.draw();
        copyTip();
        var leHeight:Float = (scale.y * frameHeight) + tip.height / 2;
        var leAngle:Float = angle * FlxAngle.TO_RAD;
        
        tip.x += origin.x - (tip.width / 2) - (leHeight * Math.sin(leAngle));
        tip.y += origin.y - (tip.height / 2) + (leHeight * Math.cos(leAngle));

        leHeight *= 2; // sure, this works
        if (leHeight < tip.height) {
            final daOffset = Math.floor(((tip.height - leHeight) / 2) / tip.scale.y);
            var leRect = new FlxRect(0, daOffset, tip.frameWidth, tip.frameHeight - daOffset);
            tip.clipRect = leRect;
        }
        else 
            tip.clipRect = null;
        
        tip.draw();
    }

    override public function kill():Void {
        tip.visible = false;
        tip.kill();

        visible = false;
        super.kill();
        resetParams();
    }

    override public function revive():Void {
        tip.visible = true;
        tip.revive();

        visible = true;
        super.revive();

        resetParams();
        handledMiss = false;
    }

    override public function destroy():Void {
        super.destroy();
    }
}