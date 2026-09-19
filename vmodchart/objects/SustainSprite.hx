package vmodchart.objects;

import flixel.FlxSprite;
import flixel.math.FlxMatrix;
import flixel.math.FlxAngle;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import flixel.util.FlxDestroyUtil;

import funkin.play.notes.Strumline;
import funkin.play.notes.notestyle.NoteStyle;
import funkin.graphics.FunkinSprite;

class SustainSprite extends FlxSprite {
    public var noteData:Null<SongNoteData>;
    public var parentStrumline:Strumline;

    public var strumTime:Float = 0;
    public var noteDirection:NoteDirection = 0;

    public var scoreable:Bool = true;
    public var hitNote:Bool = false;
    public var missedNote:Bool = false;
    public var handledMiss:Bool = false;

    public var fullSustainLength:Float = 0.0;
    public var sustainLength:Float = 0.0;

    var scrollSpeed(get, never):Float;
    function get_scrollSpeed() {
        return parentStrumline?.scrollSpeed ?? 1.0;
    }

    public var isPixel:Bool = false;
    public var visibleLimit:Float = 0.0;
    public var cover:Null<CoverSprite> = null;

    var _tileMatrix:FlxMatrix = new FlxMatrix();
    var _skewMatrix:FlxMatrix = new FlxMatrix();
    public var skew(default, null):FlxPoint = new FlxPoint();

    public function new(dir:Int, susLength:Float, ?noteStyle:NoteStyle) {
        super();
        setStyle(noteStyle);

        noteDirection = dir;
        sustainLength = fullSustainLength = susLength;
    }

    override function set_height(value:Float):Float {
		return height = Math.abs(getSustainInPixels());
	}

    override function get_height():Float {
		return Math.abs(getSustainInPixels());
	}

    public function setStyle(?noteStyle:NoteStyle) {
        if (noteStyle == null) noteStyle = new NoteStyle('funkin');
        final image = Assets.getBitmapData(noteStyle?.getHoldNoteAssetPath());
        var dirLength:Float = Strumline.DIRECTIONS.length * 2;

        loadGraphic(image, true, image.width / dirLength, image.height);

        isPixel = noteStyle?.isHoldNotePixel();
        antialiasing = !isPixel;

        if (!isPixel) 
            for (i in 0...Strumline.DIRECTIONS.length) 
                frames.frames[((i % Strumline.DIRECTIONS.length) * 2) + 1].frame.height = image.height * 0.9;

        final noteZoom:Float = noteStyle?.fetchHoldNoteScale();
        scale.set(noteZoom, noteZoom);
        origin.set(width / 2, 0);
    }

    public function resetParams():Void {
        strumTime = noteDirection = sustainLength = fullSustainLength = 0;
        hitNote = missedNote = handledMiss = false;
        noteData = null;
    }

    public function setParams(note:SongNoteData):Void {
        hitNote = missedNote = handledMiss = false;
        sustainLength = fullSustainLength = note.length;
        noteDirection = note.getDirection();
        strumTime = note.time;
        noteData = note;
    }

    function setHoldGraphic(bool:Bool):Void {
        var frameID = (noteDirection % Strumline.DIRECTIONS.length) * 2;
        if (bool) frameID++;
        frame = frames.frames[frameID];
    }

    public function getSustainInPixels():Float {
        return sustainLength * Constants.PIXELS_PER_MS * scrollSpeed;
    }

    override public function draw():Void {
        if (sustainLength > visibleLimit) super.draw();
    }

    override public function getScreenBounds(?newRect:FlxRect, ?camera:FlxCamera):FlxRect {
		if (newRect == null) newRect = FlxRect.get();
		if (camera == null) camera = getDefaultCamera();
		
		newRect.setPosition(x, y);
		if (pixelPerfectPosition) newRect.floor();

		_scaledOrigin.set(origin.x * scale.x, origin.y * scale.y);
		newRect.x += -Std.int(camera.scroll.x * scrollFactor.x) - offset.x + origin.x - _scaledOrigin.x;
		newRect.y += -Std.int(camera.scroll.y * scrollFactor.y) - offset.y + origin.y - _scaledOrigin.y;
		if (isPixelPerfectRender(camera)) newRect.floor();

		newRect.setSize(frameWidth * Math.abs(scale.x), Math.abs(getSustainInPixels()) + (frameHeight / 2) * Math.abs(scale.y));
		return newRect.getRotatedBounds(angle, _scaledOrigin, newRect);
	}

    private inline function updateSkew():Void {
		_skewMatrix.setTo(1, Math.tan(skew.y * FlxAngle.TO_RAD), Math.tan(skew.x * FlxAngle.TO_RAD), 1, 0, 0);
	}

    override function drawFrameComplex(frame:FlxFrame, camera:FlxCamera):Void {
        setHoldGraphic(true);
        var leHeight = Math.abs(scale.y) * frameHeight;

        final matrix = _matrix;
        frame.prepareMatrix(matrix, 0, checkFlipX(), false);
        matrix.translate(-origin.x, 0);
		matrix.scale(scale.x, scale.y);
		
		if (angle != 0) {
			updateTrig();
			matrix.rotateWithTrig(_cosAngle, _sinAngle);
		}

        final canSkew:Bool = skew.x != 0 || skew.y != 0;
        if (canSkew) {
			updateSkew();
			matrix.concat(_skewMatrix);
		}
		
		getScreenPosition(_point, camera);
        _point.x += origin.x - offset.x;

        if (isPixel) {
            _point.x = Math.floor(_point.x);
            _point.y = Math.floor(_point.y);
        }

        final sustainHeight:Float = getSustainInPixels() - (isPixel? leHeight : leHeight / 2);
        var leRect:FlxRect = new FlxRect(0, 0, frameWidth, frameHeight);
        var leFrame:FlxFrame = _frame;

        _tileMatrix.copyFrom(matrix);
        _tileMatrix.translate(_point.x - (sustainHeight * _sinAngle), _point.y + (sustainHeight * _cosAngle));

        if (0 > sustainHeight) {
            final daOffset:Float = -sustainHeight;
            final accountedOffset:Float = Math.max(daOffset / scale.y, 0);
            leRect.y = accountedOffset;
            leRect.height -= accountedOffset;
            _tileMatrix.translate(-daOffset * _sinAngle, daOffset * _cosAngle);

            leFrame.clip(leRect);
        }
        else if (canSkew) _tileMatrix.translate((sustainHeight * _skewMatrix.c) * _cosAngle, -(sustainHeight * _skewMatrix.b) * _sinAngle);

        camera.drawPixels(leFrame, framePixels, _tileMatrix, colorTransform, blend, antialiasing, shader);
        if (0 > sustainHeight) {
            leRect.put();
            return;
        }

        setHoldGraphic(false);
        leHeight = Math.abs(scale.y) * frameHeight;
        var lastHeight:Float = 0;

        while (lastHeight < sustainHeight) {
            final distance = sustainHeight - (lastHeight + leHeight);
            lastHeight += leHeight;
            leFrame = _frame;

            _tileMatrix.copyFrom(matrix);
            _tileMatrix.translate(_point.x - (distance * _sinAngle), _point.y + (distance * _cosAngle));
            
            if (lastHeight > sustainHeight) {
                final daOffset:Float = lastHeight - sustainHeight;
                final accountedOffset:Float = Math.max(daOffset / scale.y, 0);
                leRect.y = accountedOffset;
                leRect.width = frameWidth;
                leRect.height = frameHeight - accountedOffset;
                _tileMatrix.translate(-daOffset * _sinAngle, daOffset * _cosAngle);

                leFrame.clip(leRect);
            }
            else if (canSkew) _tileMatrix.translate((distance * _skewMatrix.c) * _cosAngle, -(distance * _skewMatrix.b) * _sinAngle);

            camera.drawPixels(leFrame, framePixels, _tileMatrix, colorTransform, blend, antialiasing, shader);
            if (lastHeight > sustainHeight) leRect.put();
        }
    }

    override public function kill():Void {
        visible = false;
        super.kill();
        resetParams();
    }

    override public function revive():Void {
        visible = true;
        super.revive();
        resetParams();
    }

    override public function destroy():Void {
        super.destroy();
        skew = FlxDestroyUtil.put(skew);
    }
}