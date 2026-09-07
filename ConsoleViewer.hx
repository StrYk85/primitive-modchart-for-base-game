import Main;
import haxe.Log;

import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFieldAutoSize;
import openfl.display.Shape;
import openfl.display.Sprite;

import funkin.modding.module.Module;
import funkin.util.logging.AnsiTrace;
import funkin.ui.FullScreenScaleMode;

class ConsoleViewer extends Module {
    var logArray:Array<String> = [];
    var LOG_SMUDGE:Float = 10;
    
    public function new() {
        super('ConsoleViewer', 0);
    }

    public override function onCreate() {
        super.onCreate();

        var oldLogs = FlxG.game.getChildByName('logViewer');
        if (oldLogs != null) FlxG.game.removeChild(oldLogs);
        Log.trace = AnsiTrace.trace;
        logArray = [];

        var oldTrace = Log.trace;
        Log.trace = function(v:Dynamic, ?infos:PosInfos) {
            logArray.push(Log.formatOutput(v, infos));
            if (logArray.length > 16) logArray.shift();
            oldTrace(v, infos);
        }

        var dummy = new Sprite();
        dummy.name = 'logViewer';
        dummy.x = LOG_SMUDGE;

        var logs = new TextField();
        logs.x = LOG_SMUDGE;
        logs.y = LOG_SMUDGE;
        logs.autoSize = TextFieldAutoSize.LEFT;
        logs.defaultTextFormat = new TextFormat('Monsterrat', 12, 0xFFFFFFFF);
        logs.selectable = false;
        logs.mouseEnabled = false;
        logs.multiline = true;

        var bg = new Shape();
        dummy.removeChildren(0, dummy.numChildren);
        dummy.addChild(bg);
        dummy.addChild(logs);
        FlxG.game.addChild(dummy);

        logViewerUpdate();
    }

    function drawEasy(bg, color, xstart, ystart, xfin, yfin) {
        bg.graphics.beginFill(color, 1);
        bg.graphics.drawRect(xstart, ystart, xfin, yfin);
        bg.graphics.endFill();
    }

    var lastHeight:Float = -1;
    var logsVisible:Bool = true;

    function logViewerUpdate() {
        var logs = FlxG.game.getChildByName('logViewer');
        if (logs != null) {
            if (!logsVisible) {
                logs.visible = false;
                return;
            }
            
            logs.visible = true;
            var logTxt = logs.getChildAt(1);
            if (logTxt != null) {
                var leText = '';
                for (log in logArray) leText += '$log\n';
                logTxt.text = leText;

                var bg = logs.getChildAt(0);
                if (bg != null) {
                    if (lastHeight != logTxt.height) {
                        lastHeight = logTxt.height;
                        bg.graphics.clear();
                        final graphicWIDTH = (FullScreenScaleMode.logicalSize.x - LOG_SMUDGE - logs.x) + FullScreenScaleMode.cutoutSize.x;
                        final graphicHEIGHT = logTxt.height + LOG_SMUDGE * 2;
                        drawEasy(bg, 0x3D3F41, 0, 0, graphicWIDTH, graphicHEIGHT);
                        final smudgy:Int = 3;
                        drawEasy(bg, 0x2C2F30, smudgy, smudgy, graphicWIDTH - (smudgy * 2), graphicHEIGHT - (smudgy * 2));
                    }
                    bg.alpha = Main.debugDisplay.backgroundOpacity;
                }
                logs.y = FullScreenScaleMode.logicalSize.y - logTxt.height - (LOG_SMUDGE * 3) + FullScreenScaleMode.cutoutSize.y;
            }
        }
    }

    public override function onUpdate(e) {
        super.onUpdate(e);
        if (FlxG.keys.justPressed.F10) logsVisible = !logsVisible;
        logViewerUpdate();
    }
}