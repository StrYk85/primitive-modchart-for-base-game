package vmodchart.extra;

import flixel.FlxSprite;
import funkin.InitState;
import funkin.modding.module.Module;
import funkin.play.notes.SustainTrail;
import funkin.play.notes.notestyle.NoteStyle;
import funkin.ui.MusicBeatState;
//import funkin.util.plugins.SidePanelPlugin;

class SustainTestState extends MusicBeatState {
    var normalSustain;
    var customSustain;
    var cover;

    function create() {
        super.create();
        normalSustain = new SustainTrail(1, 500, new NoteStyle('funkin'));
        customSustain = new SustainSprite(1, 500, new NoteStyle('funkin'));
        for (a => sus in [normalSustain, customSustain]) {
            sus.scrollFactor.set();
            sus.screenCenter();
            sus.y = FlxG.height / 2;
            add(sus);
        }

        cover = new CoverSprite(new NoteStyle('funkin'));
        cover.noteDirection = 1;
        add(cover);
        cover.playStart();
        cover.screenCenter();

        normalSustain.x -= 100;
        customSustain.x += 100;
        normalSustain.sustainLength = normalSustain.sustainLength;
    }

    var elapsedTime:Float = 0;
    function update(elapsed:Float) {
        super.update(elapsed);
        elapsedTime += elapsed;
        normalSustain.sustainLength -= Math.sin(elapsedTime * 2) * 5;
        customSustain.sustainLength = normalSustain.sustainLength;

        customSustain.angle += Math.cos(elapsedTime * 2);
        cover.angle = customSustain.angle;
        coverTwo.angle = customSustain.angle;
        cover.x = customSustain.x + (customSustain.width - cover.width) / 2 - 12;
        cover.y = customSustain.y - (cover.height / 2) + 48;
    }
}

// class RedirectModule extends Module {
//     public function new() {
//         super('RedirectModule', 0);
//     }

//     function onCreate(e) {
//         super.onCreate(e);
//         InitState.customTitleState = new SustainTestState();
//     }

//     function onStateChangeEnd(e) {
//         super.onStateChangeEnd(e);
//         if (SidePanelPlugin.instance != null && SidePanelPlugin.showGrabber) {
//             trace('#rip');
//             SidePanelPlugin.showGrabber = false;
//         }
//     }
// }