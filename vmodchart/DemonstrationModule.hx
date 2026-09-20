package vmodchart;

import funkin.play.PlayState;
import funkin.modding.module.Module;

class DemonstrationModule extends Module {
    public function new() {
        super('DemonstrationModule', 100, {state:PlayState});
    }

    function onStateChangeEnd(e) {
        super.onStateChangeEnd(e);
        final game = PlayState.instance;
        game.opponentStrumline.noteSongPosition = function(d) {
            return game.conductorInUse.stepLengthMs * game.conductorInUse.currentStep;
        }

        game.playerStrumline.noteUpdate = function(e) {
            var visDiff = e.notePosition > FlxG.height? FlxG.height : e.notePosition < 0? 0 : e.notePosition;
            var off = visDiff * (visDiff / 500) - visDiff;
            off = off > 400? 400 : off < -400? -400 : off;
            
            e.notePosition += off;
        }
    }

    function onUpdate(e) {
        super.onUpdate(e);
        final game = PlayState.instance;
        for (strumline in [game.opponentStrumline, game.playerStrumline]) {
            if (strumline != null) {
                for (a => strumNote in strumline.strumlineNotes.members) {
                    strumNote.y = (Preferences.downscroll? FlxG.height - 250 : 100) + Math.sin((strumline.getSongPosition() / 1000) + a) * 100;
                    strumNote.skew.y = Math.sin(strumline.getSongPosition() / 1000) * -25;
                }
            }
        }
    }
}