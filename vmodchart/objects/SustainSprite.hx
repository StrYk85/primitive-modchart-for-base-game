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

    public var fullSustainLength:Float = 0;
    public var sustainLength:Float = 0;

    var scrollSpeed(get, never):Float;
    function get_scrollSpeed() {
        return parentStrumline?.scrollSpeed ?? 1.0;
    }

    public var isPixel:Bool = false;
    public var cover:Null<CoverSprite> = null;

    public function new(dir:Int, susLength:Float, noteStyle:NoteStyle) {
        super();
        final assetPath:String = noteStyle.getHoldNoteAssetPath();
        final image = Assets.getBitmapData(assetPath);

        var dirLength:Float = Strumline.DIRECTIONS.length * 2;
        loadGraphic(image, true, image.width / dirLength, image.height);

        this.isPixel = noteStyle.isHoldNotePixel();
        if (isPixel) antialiasing = false;

        final noteZoom:Float = noteStyle.fetchHoldNoteScale();
        setGraphicSize(this.width * noteZoom, this.height * noteZoom);

        this.noteDirection = dir;
        this.sustainLength = susLength;
        height = Math.abs(sustainLength * Constants.PIXELS_PER_MS * scrollSpeed);
    }

    public function copySustain(oldie:SustainTrail):Void {
        noteData = oldie.noteData;
        strumTime = oldie.strumTime;
        noteDirection = oldie.noteDirection;
        fullSustainLength = oldie.fullSustainLength;
        sustainLength = oldie.sustainLength;
        parentStrumline = oldie.parentStrumline;
        scoreable = oldie.scoreable;
    }

    private function resetParams():Void {
        strumTime = 0;
        noteDirection = 0;
        sustainLength = 0;
        fullSustainLength = 0;
        noteData = null;

        hitNote = false;
        missedNote = false;
    }

    override public function draw():Void {
        if (sustainLength <= 0) return;
        super.draw();
        height = Math.abs(getSustainInPixels());
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

    var _tileMatrix:FlxMatrix = new FlxMatrix();
    var _skewMatrix:FlxMatrix = new FlxMatrix();
    public var skew(default, null):FlxPoint = new FlxPoint();

    override function drawFrameComplex(frame:FlxFrame, camera:FlxCamera):Void {
        setHoldGraphic(true);
        final matrix = this._matrix;
        frame.prepareMatrix(matrix, 0, checkFlipX() || checkFlipY(), false);
        matrix.translate(-origin.x, 0);
		matrix.scale(scale.x, scale.y);
		
		if (angle != 0) {
			updateTrig();
			matrix.rotateWithTrig(_cosAngle, _sinAngle);
		}

        final canSkew = skew.x != 0 || skew.y != 0;
        if (canSkew) {
			_skewMatrix.setTo(1, Math.tan(skew.y * FlxAngle.TO_RAD), Math.tan(skew.x * FlxAngle.TO_RAD), 1, 0, 0);
			matrix.concat(_skewMatrix);
		}
		
		getScreenPosition(_point, camera);
        _point.x += origin.x - offset.x;

        if (isPixel) {
            _point.x = Math.floor(_point.x);
            _point.y = Math.floor(_point.y);
        }

        final heightOffset = isPixel? height : height / 2;
        var sustainHeight = getSustainInPixels() - heightOffset;
        final leAngle:Float = angle * FlxAngle.TO_RAD;

        var SKEW_X = 0;
        var SKEW_Y = 0;
        if (canSkew) {
            SKEW_X = (skew.x / 2) * Math.cos(leAngle);
            SKEW_Y = (skew.y / 2) * Math.sin(leAngle);
        }

        _tileMatrix.copyFrom(matrix);
        _tileMatrix.translate(_point.x - (sustainHeight * Math.sin(leAngle)), _point.y + (sustainHeight * Math.cos(leAngle)));
        if (canSkew) _tileMatrix.translate((sustainHeight * _skewMatrix.c) * Math.cos(leAngle), -(sustainHeight * _skewMatrix.b) * Math.sin(leAngle));

        var leFrame = _frame;
        var leRect:FlxRect = new FlxRect(0, 0, frameWidth, frameHeight);

        if (0 > sustainHeight) {
            final daOffset = -sustainHeight;
            final accountedOffset = Math.max(daOffset / scale.y, 0);
            leRect.y = accountedOffset;
            leRect.height -= accountedOffset;
            _tileMatrix.translate(-daOffset * Math.sin(leAngle), daOffset * Math.cos(leAngle));
            if (canSkew) {
                final diff = (accountedOffset / frameHeight) * 2;
                _tileMatrix.translate(SKEW_X * diff, -SKEW_Y * diff);
            }

            leFrame.clip(leRect);
            camera.drawPixels(leFrame, framePixels, _tileMatrix, colorTransform, blend, antialiasing, shader);
            leRect.put();
            return;
        }
        else 
            camera.drawPixels(leFrame, framePixels, _tileMatrix, colorTransform, blend, antialiasing, shader);

        setHoldGraphic(false);
        var lastHeight = 0;

        while (lastHeight < sustainHeight) {
            final distance = sustainHeight - (lastHeight + height);
            lastHeight += height;
            leFrame = _frame;

            _tileMatrix.copyFrom(matrix);
            _tileMatrix.translate(_point.x - (distance * Math.sin(leAngle)), _point.y + (distance * Math.cos(leAngle)));
            if (canSkew) {
                SKEW_X = (lastHeight * _skewMatrix.c) * Math.cos(leAngle);
                SKEW_Y = (lastHeight * _skewMatrix.b) * Math.sin(leAngle);
                _tileMatrix.translate((sustainHeight * _skewMatrix.c) * Math.cos(leAngle) - SKEW_X, (sustainHeight * _skewMatrix.b) * -Math.sin(leAngle) + SKEW_Y);
            }
            
            if (lastHeight > sustainHeight) {
                final daOffset = lastHeight - sustainHeight;
                final accountedOffset = Math.max(daOffset / scale.y, 0);
                leRect.y = accountedOffset;
                leRect.width = frameWidth;
                leRect.height = frameHeight - accountedOffset;
                _tileMatrix.translate(-daOffset * Math.sin(leAngle), daOffset * Math.cos(leAngle));
                if (canSkew) {
                    SKEW_X = (daOffset * _skewMatrix.c) * Math.cos(leAngle);
                    SKEW_Y = (daOffset * _skewMatrix.b) * Math.sin(leAngle);
                    _tileMatrix.translate(SKEW_X, -SKEW_Y);
                }

                leFrame.clip(leRect);
                camera.drawPixels(leFrame, framePixels, _tileMatrix, colorTransform, blend, antialiasing, shader);
                leRect.put();
            }
            else
                camera.drawPixels(leFrame, framePixels, _tileMatrix, colorTransform, blend, antialiasing, shader);
        }
    }

    public function getNoteDirection():String {
        return Std.string(noteDirection % 4);
    }

    function setHoldGraphic(bool:Bool):Void {
        var frameID = (noteDirection % 4) * 2;
        if (bool) frameID++;
        frame = frames.frames[frameID];

        height = Math.abs(scale.y) * frameHeight;
		origin.set(width / 2, 0);
    }

    public function getSustainInPixels():Float {
        return sustainLength * Constants.PIXELS_PER_MS * scrollSpeed;
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
        handledMiss = false;
    }

    override public function destroy():Void {
        super.destroy();
        skew = FlxDestroyUtil.put(skew);
    }
}